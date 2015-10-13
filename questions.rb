require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database
  # Ruby provides a `Singleton` module that will only let one
  # `SchoolDatabase` object get instantiated. This is useful, because
  # there should only be a single connection to the database; there
  # shouldn't be multiple simultaneous connections. A call to
  # `SchoolDatabase::new` will result in an error. To get access to the
  # *single* SchoolDatabase instance, we call `#instance`.
  #
  # Don't worry too much about `Singleton`; it has nothing
  # intrinsically to do with SQL.
  include Singleton

  def initialize
    super('questions.db')

    self.results_as_hash = true
    self.type_translation = true
  end
end

class ModelBase

  TABLE_NAME = nil

  def self.find_by_id(id)
    params = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.const_get("TABLE_NAME")}
      WHERE
        id = ?
    SQL

    self.new(params.first)
  end

  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM #{self.const_get("TABLE_NAME")}")
    results.map { |params| self.new(params) }
  end

  def instance_variable_values
    self.instance_variables.map do |var|
      self.instance_variable_get(var)
    end[1..-1]
  end

  def instance_variable_strings
    self.instance_variables.map do |var|
      var.to_s[1..-1]
    end[1..-1].join(",")
  end

  def instance_variable_marks
    self.instance_variables.map do |var|
      "?"
    end[1..-1].join(",")
  end

  def instance_variable_setter
    self.instance_variables.map do |var|
      (var.to_s[1..-1] + "= ?")
    end[1..-1].join(",")
  end

  def self.options_hash_where(options)
    options.map do |k,v|
      if v.is_a?(String)
        "#{k} = '#{v}'"
      else
        "#{k} = #{v}"
      end
    end.join(" AND ")
  end

  def self.where(options = {})
    if options.is_a? Hash
      opts = options_hash_where(options)
    else
      opts = options
    end
    results = QuestionsDatabase.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.const_get("TABLE_NAME")}
      WHERE
        #{opts}
  SQL
    results.map { |params| self.new(params) }
  end

  def self.method_missing(method_name, *vals)
    if method_name.to_s.start_with? "find_by"
      keys = method_name[8..-1].split('_')
      keys.delete("and")
      store = Hash.new
      keys.each_with_index do |key, i|
        store[key] = vals[i]
      end
      where(store)
    else
      super
    end

  end

  def save
    if self.id.nil?
      params = instance_variable_values
      QuestionsDatabase.instance.execute(<<-SQL, *params)
        INSERT INTO
          #{self.class.const_get("TABLE_NAME")} (#{instance_variable_strings})
        VALUES
          (#{instance_variable_marks})
      SQL

      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      params = instance_variable_values + [self.id]
      QuestionsDatabase.instance.execute(<<-SQL, *params)
        UPDATE
          #{self.class.const_get("TABLE_NAME")}
        SET
          #{instance_variable_setter}
        WHERE
          id = ?
      SQL
    end
  end

end

class User < ModelBase

  TABLE_NAME = 'users'

  def self.find_by_name(fname, lname)
    params = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL

    User.new(params.first)
  end

  attr_accessor :id, :fname, :lname
  def initialize(params={})
    @id = params["id"]
    @fname = params["fname"]
    @lname = params["lname"]
  end

  def authored_questions
    Question.find_by_author_id(self.id)
  end

  def authored_replies
    Reply.find_by_author_id(self.id)
  end

  def followed_questions
    followed_questions_for_user_id(self.id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(self.id)
  end

  def average_karma
    QuestionsDatabase.instance.execute(<<-SQL, self.id)
      SELECT DISTINCT
        COUNT(question_likes.question_id) / COUNT(DISTINCT questions.id) AS average
      FROM
        questions
      LEFT OUTER JOIN question_likes
      ON
        question_likes.question_id = questions.id
      WHERE
        questions.user_id = ?
      GROUP BY questions.user_id
  SQL
  end

end

class Question < ModelBase

  TABLE_NAME = 'questions'

  def self.find_by_author_id(author_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        user_id = ?
    SQL
    results.map { |params| Question.new(params) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end


  attr_accessor :id, :title, :body, :user_id
  def initialize(params={})
    @id = params["id"]
    @title = params["title"]
    @body = params["body"]
    @user_id = params["user_id"]
  end

  def author
    User.find_by_id(self.user_id)
  end

  def replies
    Reply.find_by_question_id(self.id)
  end

  def followers
    followers_for_question_id(self.id)
  end

  def likers
    QuestionLike.likers_for_question_id(self.id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(self.id)
  end
end

class Reply < ModelBase

  TABLE_NAME = 'replies'

  def self.find_by_author_id(author_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL
    results.map { |params| Reply.new(params) }
  end

  def self.find_by_question_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
  SQL
  results.map { |params| Reply.new(params) }
  end

  attr_accessor :id, :body, :parent_id, :user_id, :question_id
  def initialize(params={})
    @id = params["id"]
    @parent_id = params["parent_id"]
    @question_id = params["question_id"]
    @user_id = params["user_id"]
    @body = params["body"]
  end

  def author
    User.find_by_id(self.user_id)
  end

  def question
    Question.find_by_id(self.question_id)
  end

  def parent_reply
    Reply.find_by_id(self.parent_id)
  end

  def child_replies
    results = QuestionsDatabase.instance.execute(<<-SQL, self.id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_id = ?
    SQL
    results.map { |params| Reply.new(params) }
  end
end

class QuestionFollow
  def self.followers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      users.*
    FROM
      users
    INNER JOIN
      question_follows
    ON users.id = question_follows.user_id
    WHERE
      question_follows.question_id = ?
  SQL
  results.map { |params| User.new(params) }
  end

  def self.followed_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
    SELECT
      *
    FROM
      questions
    INNER JOIN
      question_follows
    ON questions.id = question_follows.question_id
    WHERE
      question_follows.user_id = ?
  SQL
  results.map { |params| Question.new(params) }
  end

  def self.most_followed_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      INNER JOIN
        question_follows
      ON questions.id = question_follows.question_id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(question_follows.question_id) DESC
      LIMIT ?
    SQL
    results.map { |params| Question.new(params) }
  end
end

class QuestionLike

  def self.likers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      users.*
    FROM
      users
    INNER JOIN
      question_likes
    ON users.id = question_likes.user_id
    WHERE
      question_likes.question_id = ?
  SQL
  results.map { |params| User.new(params) }

  end

  def self.num_likes_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      COUNT(question_likes.question_id)
    FROM
      questions
    INNER JOIN
      question_likes
    ON questions.id = question_likes.question_id
    WHERE
      questions.id = ?
    GROUP BY questions.id
  SQL

  results.map { |params| User.new(params) }
  end

  def self.liked_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
    SELECT
      questions.*
    FROM
      questions
    INNER JOIN
      question_likes
    ON questions.id = question_likes.question_id
    WHERE
      question_likes.user_id = ?
    GROUP BY questions.id
  SQL

  results.map { |params| User.new(params) }
  end

  def self.most_liked_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        questions
      INNER JOIN
        question_likes
      ON questions.id = question_likes.question_id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(question_likes.question_id) DESC
      LIMIT ?
    SQL
    results.map { |params| Question.new(params) }
  end

end


#user = User.find_by_name('Fred', 'Sladkey')
# user.authored_replies.each do |reply|
#   p reply.body
# end
# users.each { |user| puts user.title }
#user.authored_questions.each {|q| puts q.title}



# user = User.find_by_name('Frank', 'Sladkey')
# puts user.fname
# user.fname = 'Frank'
# user.save
# user = User.find_by_name('Fred', 'Sladkey')
# puts user.fname
