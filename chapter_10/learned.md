# Active Support のConcern モジュール
モジュールをインクルードすると、インスタンスメソッドとクラスメソッドの両方が手に入る。
これを実現しているのがActiveSupport:: Concern。
「クラスメソッドをインクルーダーに 追加する」機能をカプセル化して、その他のモジュールでも簡単に使えるようにしているのだ


## 10.1 Concern 以前の Rails

### 10.1.1 include と extend のトリック
```ruby
class Base
  include HogeModule
end

module HogeModule
  def instance_method
   # ...
  end

  def self.included(base)
    # baseはこのmoduleをincludeしたクラス/モジュールが入る
    base.extend ClassMethods
  end

  module ClassMethods
    def class_method
      # ...
    end
  end
end
```

上のように書くことで、Base はインスタンスメソッドと、クラスメソッドの両方を手に入れる
見れば分かる通り、クラスメソッドを定義するあらゆるモジュールは、インクルーダーを拡張する included というフックメソッドを定義しなければいけない。
Rails のような巨大なコードベースでは、こうしたフックメソッドが何十ものモジュールに重複しており、その結果include と extend のトリックはやる価値があるのだろうかと疑問視されることになった
下記のように1行足すだけで同じことが実現できるからだ

```ruby
class Base
  include HogeModule
  extend HogeModule::ClassMethods
end
```

### 10.1.2 include の連鎖の問題
問題は、フックメソッドを準備しなければならないことだけではない。
それは、インクルードするモジュールが、また別のモジュールをインクルードしているにおきる

```ruby
module SecondLevelModule
  def self.included(base)
   base.extend ClassMethods
  end

  def second_level_instance_method; 'ok'; end

  module ClassMethods
    def second_level_class_method; 'ok'; end
  end
end

module FirstLevelModule
  def self.included(base)
   base.extend ClassMethods
  end

  def first_level_instance_method; 'ok'; end

  module ClassMethods
    def first_level_class_method; 'ok'; end
  end

  include SecondLevelModule
end

class BaseClass
  include FirstLevelModule
end
```

このときインスタンスメソッドは問題なくBaseClassにとりこまれる
```ruby
BaseClass.new.first_level_instance_method # => "ok"
BaseClass.new.second_level_instance_method # => "ok"
```

また、inlucde と extend のトリックのおかげで、FirstLevelModule::ClassMethods のメソッドは、BaseClass のクラスメソッドになっている
```ruby
BaseClass.first_level_class_method # => "ok"
```

が、SecondLevelModule::Class Methods のメソッドはBaseClass のクラスメソッドにならない
```ruby
BaseClass.second_level_class_method # => NoMethodError
```

これはRails2では下記のように解決されたがこれはいい方法ではなかった
```ruby
module FirstLevelModule
  def self.included(base)
    base.extend ClassMethods
    base.send :include, SecondLevelModule
  end
# ...
```
これでは、システム全体の柔軟性が落ちてしまう。
- Rails は、ファーストレベルのモジュールを識別する必要がある
- それぞれのモジュールも自分がファーストレベルかどう かを把握する必要がある


**ここまででみてきたような下記問題を解決するためにActiveSupport::Concern は生まれた**
- いくつものモジュールに同じようなボイラープレートコードが必要になる
- 複数のレベルでモジュールをインクルードするとうまく動作しなくなる


## 10.2 ActiveSupport::Concern
ActiveSupport::Concern は、include と extend のトリックをカプセル化して、includeの連鎖の問題を解決
実際に使うイメージは下記

```ruby
module MyConcern
  extend ActiveSupport::Concern

  def an_instance_method; " インスタンスメソッド "; end

  module ClassMethods
    def a_class_method; " クラスメソッド "; end
  end
end

class MyClass
  include MyConcern
end

MyClass.new.an_instance_method # => " インスタンスメソッド "
MyClass.a_class_method # => " クラスメソッド "
```

## 10.2.1 Concern のソースコードの概観
`extended`と`append_features`という2つの重要なメソッドからなる

### extended

```ruby
module ActiveSupport
  module Concern
    class MultipleIncludedBlocks < StandardError #:nodoc:
      def initialize
        super "Cannot define multiple 'included' blocks for a Concern" end
      end

      def self.extended(base)
        base.instance_variable_set(:@_dependencies, [])
      end

      # ...
```

エクステンダーにクラスインスタンス変数(p.114)である @_ dependencies を定義するだけ


### append_features
Concern は、独自の append_features を定義しており、Ruby のコアのメソッドをオーバーライドしている

#### Module#append_features
http://ref.xaio.jp/ruby/classes/module/append_features

Module#includeメソッドの本体
includeメソッドの実装は、引数の各モジュールに対してappend_featuresメソッドとincludedメソッドを呼び出すというもの。
インクルードの機能の本体はappend_featuresにある。

→ append_features をオーバーライドすると、(superしない限り)モジュールが一切インクルードされなくなる


#### Concern#append_features
ここまでで明らかになっていること
```
Concern をエクステンドしたモジュールは
- クラス 変数 @_dependencies を手に入れる
- オーバーライドした append_features を手に入れる
```

**Concern#append_features の中身**
簡単にいうと
```
concernのなかで、別の concernをインクルードしないのである。
concern がお互いにインクルードしようとしていたら、 依存関係のグラフのなかにリンクするだけだ。
concern ではないモジュールに別の concern がインクルードされたら、すべての依存関係をインクルーダーに一気に流し込む
```

```ruby
module ActiveSupport
  module Concern
    def append_features(base)
      # このスコープのなかでは、selfはconcern
      # base はincludeをよんだモジュール

      # 1. インクルーダーが concern かどうかを確認
      # クラス変数 @_dependencies があれば、それが concern だとわかる
      if base.instance_variable_defined?(:@_dependencies)
        # インクルーダーの継承チェーンに自身を追加する代わりに、依存関係のリストに自身を追加している
        base.instance_variable_get(:@_dependencies) << self
        # インクルードが発生しなかったことを示すために、falseを戻している
        return false
      else
        # すでにインクルーダーの継承チェーンに自身が追加されていないかどうかを確認(他のconcernがインクルードされるなどして)
        return false if base < self
        # インクルーダーに依存関係を再帰的にインクルードしていく
        @_dependencies.each { |dep| base.send(:include, dep) }
        # Module.append_features を呼び出して、継承チェーンに自分自身を追加
        super
        # インクルーダーに ClassMethods モジュール をエクステンドさせる
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        # ...
      end

    # ...
  # ...
```


```ruby
module SecondLevelModule
  extend ActiveSupport::Concern

  def second_level_instance_method; " インスタンスメソッド "; end

  module ClassMethods
    def second_level_class_method; " クラスメソッド "; end
  end
end

module FirstLevelModule
  extend ActiveSupport::Concern
  include SecondLevelModule

  def first_level_instance_method; " インスタンスメソッド "; end

  module ClassMethods
    def first_level_class_method; " クラスメソッド "; end
  end
end

class MyClass
  include FirstLevelModule
end
```

1. MyClassがFirstLevelModuleをincludeしようとする

2. FirstLevelModuleがSecondLevelModuleをincludeしようとする

3. FirstLevelModuleの@_dependenciesにSecondLevelModuleが入る

4. FirstLevelModuleの@_dependenciesをもとにMyClassに再帰的にincludeが実行される

5. FirstLevelModuleがMyClassにincludeされる(superによって)

6. MyClassがFirstLevelModuleの ClassMethods をエクステンドする


疑問：second_level_class_methodってどうやってMyClassに生えてるの？
このへんが理解できていないせいな気がする
```
ClassMethodsの参照は Kernel#const_get を使って取得する必要がある
コードが物理的に配置されている Concern モジュールではなく、self のスコープで定数を読み込まなければいけないから
```
