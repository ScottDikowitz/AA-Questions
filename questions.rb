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
        #{TABLE_NAME}
      WHERE
        id = ?
    SQL

    Self.new(params.first)
  end

  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM #{TABLE_NAME}")
    results.map { |params| Self.new(params) }
  end

  def save
    if self.id.nil?
      params = [self.fname, self.lname]
      QuestionsDatabase.instance.execute(<<-SQL, *params)
        INSERT INTO
          users (fname, lname)
        VALUES
          (?, ?)
      SQL

      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      params = [self.fname, self.lname, self.id]
      QuestionsDatabase.instance.execute(<<-SQL, *params)
        UPDATE
          users
        SET
          fname = ?,
          lname = ?
        WHERE
          id = ?
      SQL
    end
  end

end

class User < ModelBase

  TABLE_NAME = users

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
