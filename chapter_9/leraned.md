# Active Recordの設計

Active Record とは、Rails に含まれるライブラリであり、Ruby のオブジェクトをデータベース のテーブルにマッピングするものである。
この機能は、オブジェクトリレーショナルマッピングと呼 ばれ、リレーショナルデータベース(永続化に使用)とオブジェクト指向プログラミング(ビジネスロジックに使用)の両方のよいところが得られる

## 9.1 Active Record の短いサンプル
ActiveRecord::Base は、Active Record で最も重要なクラスだ。
データベースコネクションを開 くといった重要なクラスメソッドが含まれている。また、Duck クラスなどのすべてのマッピング クラスのスーパークラスにもなる

## 9.2 Active Record はどのようにまとめられているか

### 9.2.1 オートローディングの仕組み
Active Record は、2 つのライブラリに大きく依存している。Active Support と Active Modelだ。それぞれをすぐにロードしている。
ActiveSupport::Autoload モジュールでは、autoload が定義されている。
このメソッドでは、モジュール名を最初に使ったとき に、自動的にモジュール(やクラス)のソースコードを探して、require するという命名規約が使われている



### 9.2.2 ActiveRecord::Base
```ruby
module ActiveRecord class Base
extend ActiveModel::Naming
extend ActiveSupport::Benchmarkable extend ActiveSupport::DescendantsTracker extend ConnectionHandling
extend QueryCache::ClassMethods
extend Querying
extend Translation
extend DynamicMatchers
extend Explain
extend Enum
extend Delegation::DelegateCache
include Core
include Persistence
include NoTouching
include ReadonlyAttributes
include ModelSchema
include Inheritance
include Scoping
include Sanitization
include AttributeAssignment
include ActiveModel::Conversion include Integration
include Validations
include CounterCache
include Locking::Optimistic
include Locking::Pessimistic include AttributeMethods
include Callbacks
include Timestamp
include Associations
include ActiveModel::SecurePassword include AutosaveAssociation
include NestedAttributes
include Aggregations include Transactions include Reflection include Serialization include Store
include Core
end
ActiveSupport.run_load_hooks(:active_record, Base)
end
```

- 数十あるモジュールを extend および include しているだけ
- run_load_hooks を呼び出している行は、オートロードされたモジュールが設定用のコードを呼び出せるようにするもの

**最も重要なクラスである ActiveRecord::Base はモジュールの集まり**

ActiveRecord::Base は、モジュールのソース コードを require してからモジュールを include する必要がない。
モジュールを include するだけ でいい。オートローディングのおかげで、Base などのクラスは最小限のコードで、多くのモジュールをインクルードできるようになっている

例えば、save のような永続化のメソッドは、ActiveRecord::Persistence にある。

### 9.2.3 Validations モジュール
- valid? -> ActiveRecord::Validations
- validate -> ActiveRecord::Validations がincludeしているActiveModel::Validations

#### 疑問1：クラスがモジュールをインクルードすると、通常はインスタンスメソッドが手に入るが、 validate は ActiveRecord::Base のクラスメソッドである
モジュールをインクルードしたときに、インスタンスメソッドと一 緒にクラスメソッドも手に入っている。
この仕組は10章で

#### 疑問2：なぜ ActiveRecord::Base は ActiveRecord::Validations と ActiveModel::Validations を必要とするのか
もともとは、ActiveModelは存在せずActiveRecordだけだったが、Active Record が成長していくにつれライブラリを 2 つに分割する必要が出てきた

結果
Active Record -> 保存や読み込みなどのデータベースの操作
Active Model -> ブジェクトのアトリビュートを保持したり、どのアトリビュー トが妥当かを追跡したりするオブジェクトモデルの操作

具体的に言うと、
valid? メソッドはデータベースに手を 出さなければいけないので(オブジェクトがデータベースに保存されたかどうかを確認する必要があるので)、ActiveRecord::Validations に残り、
validate はデータベースとは関係なく、オブジェクトのアトリビュートのことだけを気にかければいいので、ActiveModel::Validations に移動したのである


## 9.3 学習したこと
Rails を普通にインストールすると、Base クラスにはインスタンスメソッドが 300 個以上、 クラスメソッドは驚きの 550 個以上も含まれている

Active Record の設計から得られる教訓
**設計技法は絶対的なものではなく、設計 技法は使用している言語によって違ってくる**



## note

### ActiveRecordが読み込まれるまでの順序
1. require 'active_record'


2. require 'active_support' / require 'active_model' / autoload
```ruby gems/activerecord-4.1.0/lib/active_record.rb
require 'active_support'
require 'active_model'

# ...
module ActiveRecord
extend ActiveSupport::Autoload
autoload :Base
autoload :NoTouching
autoload :Persistence
autoload :QueryCache
autoload :Querying
autoload :Validations
# ...
```

3. それぞれのモジュールからメソッドが追加される



### valid?について
> valid? メソッドはデータベースに手を 出さなければいけないのでActiveRecord::Validationsに残り

とあったがこれは、下記のようなバリデーションがひつようになるから
- uniqueness
- belongs_to における存在確認


なお、valid? は ActiveModel::Validationsにも存在する
https://github.com/rails/rails/blob/master/activemodel/lib/active_model/validations.rb#L334

ActiveRecord::Validations#valid? はsuperでActiveModel::Validations#valid? を用いている
