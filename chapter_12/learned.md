# アトリビュートメソッドの進化
現実の大規模なシステムでメタプログラミングを使ったときに何が起きるのかと、今でも疑問に思っていることだろう。
すぐにコードが複雑になり、予期しない方向に進んでいくこの乱雑な世界のなかで、このような洗練された技法をどのように使えばいいのだろう?
この質問に答えるために、Railsの最も有名な機能であるアトリビュートメソッドを探索してこのツアーを締めくくる

### 12.2.1 Rails1:はじめはシンプル
method_missingを用いた数十行の実装

```ruby
module ActiveRecord
  class Base
    def initialize(attributes = nil)
      @attributes = attributes_from_column_definition # ...
    end

    def attribute_names
      @attributes.keys.sort
    end

    alias_method :respond_to_without_attributes?, :respond_to?

    def respond_to?(method)
      @@dynamic_methods ||= attribute_names +
      attribute_names.collect { |attr| attr + "=" } +
      attribute_names.collect { |attr| attr + "?" }
      @@dynamic_methods.include?(method.to_s) ? true : respond_to_without_attributes?(method)
    end

    def method_missing(method_id, *arguments)
      method_name = method_id.id2name

      if method_name =~ read_method? && @attributes.include?($1)
        return read_attribute($1)
      elsif method_name =~ write_method?
        write_attribute($1, arguments[0])
      elsif method_name =~ query_method?
        return query_attribute($1)
      else
        super
      end
    end

    def read_method?() /^([a-zA-Z][-_\w]*)[^=?]*$/ end
    def write_method?() /^([a-zA-Z][-_\w]*)=.*$/ end
    def query_method?() /^([a-zA-Z][-_\w]*)\?$/ end
    def read_attribute(attr_name) # ...
    def write_attribute(attr_name, value) #...
    def query_attribute(attr_name) # ...
```

### Rails 2:パフォーマンスに注目
存在しないメソッドを呼び出すと、Ruby は継承チェーンを上ってメソッドを探しに行く。
そして、最終的にBasicObjectに到着し、そこでもメソッドが見つからなければ、一番下まで戻ってmethod_missingを呼び出す。

**→ Rails1のじっそうではパフォーマンスが悪い**

■そこで取られた解決方法  
**ゴーストメソッドと動的メソッドの両方を取り入れた**
最初にアトリビュートにアクセスしたときには、ActiveRecord::Base#method_missing が、ゴーストメソッドを本物のメソッドに変える。
method_missing はすべてのデータベースカラムの読み取り、書き込み、問い合わせ用のアクセサを動的に定義している。
あらためてアトリビュートを呼び出すと、 本物のアクセサのメソッドが待ち構えているので、再度 method_missing に入る必要はない。

### 12.2.3 Rails3と4: もっと特殊なケース
さらにパフォーマンスを上げるための変更が加わっている。  
アトリビュートアクセサを定義するときに、UnboundMethod に変更してから、メソッドキャッシュに保存している。
別のクラスが同じ名前のアトリビュートを持っていて、同じアクセサを必要としていた場合、Rails4では、先に定義したアクセサをキャッシュから取り出して、別のクラスに束縛する。
異なるクラスに同じ名前のアトリビュートがあったとしても、Rails はアクセサメソッドの一式を定義しておいて、すべてのアトリビュートのメソッドに再利用するのである


## 12.3 学習したこと
Railsのやり方は「最初から正しくやる」よりも「進化的設計」に傾いている。
その理由は大きく2つある。まずは、Rubyが柔軟性の高い言語だからだ。もうひとつの理由は、最初から完璧なメタプログラミングのコードを書くことは難しいからだ。すべてのコーナーケースを明らかにすることは困難である。

コードはできるだけシンプルに保とう。必要になったら複雑にしていこう。
最初は一般的なケースを正しく扱えるコードを書くべきだ。あとから特殊ケースを追加できるように、シンプルにしておくのである
