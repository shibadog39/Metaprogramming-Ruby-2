# alias_method_chain の盛衰
名声を極めた alias_method_chain メソッドが不評 を招き、最終的に Rails のコードベースから姿を消した話

## 11.1 alias_method_chain の登場

- alias_method_chainが使われていた例
```ruby
# gems/activerecord-2.3.2/lib/active_record/validations.rb

module ActiveRecord
  module Validations

    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        alias_method_chain :save, :validation
        alias_method_chain :save!, :validation
      end
      # ...
    end

```

### 11.1.1 alias_method_chain を使う理由

```ruby
module Greetings
  def greet
    "hello"
  end
end

class MyClass
  include Greetings

  def greet_with_enthusiasm
    "Hey, #{greet_without_enthusiasm}!"
  end

  alias_method :greet_without_enthusiasm, :greet
  alias_method :greet, :greet_with_enthusiasm
end
```

既存のメソッドを新しい機能で包み込むアイデアは、「メソッド」と「メソッド_with_機能」と「メソッド_without_機能」によって実現される。
最初の2つは新機能を持っているが、最後は新機能を持っていない。
このように至るところにエイリアスを複製する代わりに、Rails ではメタプログラミングの技法を使って、すべてのエイリアスを用意してくれる。
その名前は、Module#alias_method_chain であり、以前は Active Support ライブラリの一部だった


### 11.1.2 alias_method_chain の中身

```ruby
class Module
  # target=ターゲットとなるメソッド、 feature=新機能の名前
  def alias_method_chain(target, feature)
    # Strip out punctuation on predicates or bang methods since
    # e.g. target?_without_feature is not a valid method name.
    aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
    yield(aliased_target, punctuation) if block_given?

    with_method = "#{aliased_target}_with_#{feature}#{punctuation}"
    without_method = "#{aliased_target}_without_#{feature}#{punctuation}"

    alias_method without_method, target
    alias_method target, with_method

    case
    when public_method_defined?(without_method)
      public target
    when protected_method_defined?(without_method)
      protected target
    when private_method_defined?(without_method)
      private target
    end
  end
end
```

### 11.1.3 Validations の見納め

```ruby
# gems/activerecord-2.3.2/lib/active_record/validations.rb

module ActiveRecord
  module Validations

    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        alias_method_chain :save, :validation
        alias_method_chain :save!, :validation
      end
      # ...
    end

# gems/activerecord-2.3.2/lib/active_record/validations.rb
module ActiveRecord
  module Validations
    def save_with_validation(perform_validation = true)
      if perform_validation && valid? || !perform_validation
        save_without_validation
      else
        false
      end
    end

    def save_with_validation!
      if valid?
        save_without_validation!
      else
        raise RecordInvalid.new(self)
      end
    end
```

## 11.2 alias_method_chain の衰退
alias_method_chainの問題
- メソッドのリネームとシャッフルを繰り返したことで、実際に呼び出しているメソッドがどのバージョンかを追跡するのが難しくなってしまった
- ほとんどの場合において存在そのものが不要
  - 継承で十分な場合が多い
  - 現在の ActiveRecord::Validations は、alias_method_ chain よりも通常のオーバーライドを用いている
  - Ruby 2.0 からModule#prependが利用可能


## 11.3 学習したこと
メタプログラミングによってコードが複雑になる可能性があり、以前からある簡単な技法を見逃す恐れがある。
メタプログラミングを使わなくても、昔ながらの簡潔なオブジェクト指向プログラミングの技法が使えることもある。
目的地に到達するために、メタプログラミングよりもシンプルな方法がないかと自分に問いかけよう
