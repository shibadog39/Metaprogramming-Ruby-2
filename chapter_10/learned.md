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
