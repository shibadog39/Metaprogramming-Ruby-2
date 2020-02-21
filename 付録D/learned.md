# 付録D から騒ぎ
Nullオブジェクト、ゴーストメソッド、ブラックホールなどに囲まれたRubyの底なしのnilを眺める

```ruby
class Alarm
  def device
    CONFIGURATION.current_user.device
  end

  def send_default
    10.times { device.ring }
  end

  def send_discreet
    device.ring
  end
end
```
あるユーザーのデバイスが紛失していた場合、deviceはnilを返すことになる。
その解決策として各メソッドで下記のようなガード節を使う方法が考えられる

```ruby
def send_default
  return unless device

  10.times { device.ring }
end
```

しかしこれだと全メソッドで同様の記述を行う必要があるのでもっといい方法で実現したい

## D.1 Null オブジェクト

```ruby
class NullDevice
  def flash; end
  def ring; end
end

class Alarm
  def device
    CONFIGURATION.current_user.device || NullDevice.new
  end

  # ...
end
```
これでdeviceメソッドは常にringやflashを安全に呼び出せる「何か」を戻すことになる
ただ、これだとRubyの強みを最大限活かせていない

## D.2 Ruby の強みを活かす
ほとんどの言語では、初期化されていないオブジェクトは何も参照していない。
だが Ruby では 「何もない」ものなど存在しない。nilは実在のオブジェクトであり、NilClass の唯一のインスタンスなのだ

Ruby のもうひとつの強力な機能は、クラスがクローズしないということである。
既存のクラス を再オープンして、いつでも修正を加えることができる。NilClass クラスも例外ではない

```ruby
class NilClass
  def flash; end
  def ring; end
end
```

だが、特定のドメインのメソッドを追加して NilClass クラスを汚すのはあまり良い考えではない
たとえば、method_missing を実装すれば、存在しないメソッド呼び出しを捕まえること ができる


```ruby
class NilClass
  # flash()、ring()、その他のメソッド呼び出しは、
  # method_missing() にたどり着く。
  # アスタリスク(*)は引数を無視するという意味。
  def method_missing(*)
  end
end
```

これなら新しいメソッド(たとえば beep メソッド)がデバイスに追加されても、nil にメソッドを追加する必要がない。

このような nil を使った Null オブジェクトのことをブラックホールと呼ぶ。
ブラックホールは、初期化されていない参照の問題を回避しつつ、メソッド呼び出しを無限の Null オブジェクトの穴に吸い込んでいく。
ただし、ブラックホールにはバグに気づきにくいという問題もある


基本的にはNilClassに#method_missingをすることはない。アプリケーション層でのエラーは出ずともデータ不整合になる可能性が高いため。
