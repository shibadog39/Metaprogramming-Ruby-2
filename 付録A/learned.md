# よくあるイディオム

## A.1 ミミックメソッド
メソッド呼び出しを偽装することで、Rubyは言語のコア部分を相対的に小さく整然と保ったまま、関数のような便利なメソッドを数多く提供できている

```ruby
# ex1
puts 'hello world!'
puts('hello world!')

# ex2
class C
  def my_attribute=(value)
    @p = value
  end
end

obj = C.new
obj.my_attribute= 'Hi!'
obj.my_attribute=('Hi!')
```

### column アトリビュートの不具合

```ruby
class MyClass
  attr_accessor :my_attr

  def set_attribute(n)
    # my_attr = だとローカル変数と認識されてしまう
    self.my_attr = n
  end
end
```

※ このときattr_accessorがprivateだとしても、正常に呼び出せる
通常、レシーバself を明示していないprivate メソッドの呼び出しはできない。
だがこの難問は、Ruby の特例によって解決できる。my_attribute= などのアトリビュートのセッターは、privateであっても selfをつけて呼び出せるのだ。
これはローカル変数だと認識されてしまうことのほうが都合が悪いことが多いからである。

## A.2 nilガード
```ruby
def elements
  @a ||= []
end
```
false(nil もそうだが)になる値を持つ変数を初期化するときに nilガードは使うべきではない。

## A.3 自己 yield
メソッドにブロックを渡すときは、メソッドが yield を使ってブロックをコールバックすることを期待している。
コールバックが便利なのは、ブロックにオブジェクト自身を渡せるところだ。

### A.3.1 Faraday の例
``` ruby
require 'faraday'
conn = Faraday.new("https://twitter.com/search") do |faraday|
   faraday.response      :logger
   faraday.adapter       Faraday.default_adapter
   faraday.params["q"]   = "ruby"
   faraday.params["src"]  = "typd"
end

module Faraday
  class << self
    def new(url = nil, options = {})
      # ...
      # Faraday.new はFaraday::Connectionオブジェクトを生成してから戻している
      Faraday::Connection.new(url, options, &block)
    end
  # ...

  class Connection
    def initialize(url = nil, options = {})
      # ...
      # 任意のブロックを受け取り、新しく生成した Connection オブジェクトを渡して yield している
      yield self if block_given?
      # ...
    end
```

### A.3.2 tap の例
```ruby
class Object
  def tap
    yield self
    self
  end
end
```

## A.4 Symbol#to_proc
```ruby
class Symbol
  def to_proc
    Proc.new {|x| x.send(self) }
  end
end

names = ['bob', 'bill', 'heather']
names.map(&:capitalize.to_proc) # => ["Bob", "Bill", "Heather"]

# & 修飾はすべてのオブジェクトに適用できるものだ。
# そして、 それが to_proc を呼び出してオブジェクトを Proc にしているのだから、以下のように書ける
names.map(&:capitalize) # => ["Bob", "Bill", "Heather"]
```

# 勉強会にて
## SymbolのProc変換他にもこういう書き方もできる

```
method = 2.method(:*)
[1,2,3].map(&method)
=> [2, 4, 6]  
```
2 * i ができる

----

```
[1,2,3].each(&method(:puts))
1
2
3
=> [1, 2, 3]
```
tapぽい使い方

## tap / then / yield_self
https://techracho.bpsinc.jp/kazz/2019_12_23/85305
