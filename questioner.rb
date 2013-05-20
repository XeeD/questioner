require "rubygems"
require "active_support/core_ext"
require "colorize"
require "readline"
require "unicode_utils/downcase"

class Question
  attr_reader :tries, :content

  def initialize(content, answers)
  	@content = content
  	@answers = answers.
                      split(",").
                      map(&:strip).
                      uniq.
                      map { |answer_text| Answer.new(answer_text) }

  	@answered_corretly = false
    @tries = 0
  end

  def is_corrent_answer?(user_answer_text)
    @tries += 1

    user_answers = user_answer_text.split(/, */).map(&:strip).uniq
    user_remaining = user_answers.dup

    @answers.each do |answer|
      user_remaining = user_remaining.reject do |user_answer|
        answer.is_corrent_answer?(user_answer)
      end
    end

    AnswerResult.new(user_answers - user_remaining, user_remaining, self)
  end

  def answer_list
    @answers.
      map { |answer|
            if answer.answered_corretly?
              "* #{answer.answer_text}".colorize(:green)
            else
              "- #{answer.answer_text}".colorize(:yellow)
            end
      }.join("\n")
  end

  def answers_count
    @answers.length
  end

  def answered_answers_count
    @answers.find_all { |answer| answer.answered_corretly? }.length
  end

  def answered_corretly?
    @answers.find { |answer| !answer.answered_corretly? }.nil?
  end

  class Answer
    attr_reader :answer_text

    def initialize(answer_text)
      @answer_text = answer_text.strip
      @answered_corretly = false
    end

  	def answered_corretly?
  		@answered_corretly
    end

    def is_corrent_answer?(answer_text)
      if UnicodeUtils.downcase(answer_text.strip) == UnicodeUtils.downcase(@answer_text)
        @answered_corretly = true
      else
        false
      end
    end
  end

  class AnswerResult
    def initialize(correct_answers, incorrect_answers, question)
      @correct_answers = correct_answers
      @incorrect_answers = incorrect_answers
      @question = question
    end

    def to_s
      if all_correct? && @incorrect_answers.empty?
        " Otázka zodpovězena na #{@question.tries} pokusů ".colorize(:black).on_green

      elsif @correct_answers.empty?
        "Špatná odpověď".colorize(:red)

      elsif @incorrect_answers.empty?
        "Správně, ale to není vše".colorize(:yellow)

      else
        "Částečně správně (#{@correct_answers.join(", ").colorize(:green)}), částečně špatně (#{@incorrect_answers.join(", ").colorize(:red)})"
      end
    end

    def all_correct?
      @question.answered_corretly?
    end

    def partially_correct?
      !@correct_answers.empty?
    end
  end
end

class Quiz
  def initialize(questions_and_answers)
  	@questions = questions_and_answers.map { |text|
      question, answers = text

      if question.blank? || answers.blank?
        puts "Chybný formát otázky: #{text.join("\t")}".colorize(:red)
        next
      end

      Question.new(question, answers)
    }.compact
  end

  def run
    greet
    quiz_loop
  end

  def greet
    puts "\n\n"
    message = "Kvíz začíná!".colorize(:green)
    puts message
    puts "=" * message.length
  end

  def quiz_loop
    loop do
      question = current_question

      if question.nil?
        puts "Vše zodpovězeno"
        break
      end

      puts " Otázka: #{question.content} ".colorize(:white).on_blue

      input = Readline.readline("> ", true).chomp

      case input
      when "exit"
        break

      when "h", "hint"
        puts question.answer_list

      when "c", "count_answers"
        puts "#{question.answered_answers_count}/#{question.answers_count}"

      else
        result = question.is_corrent_answer?(input)
        puts result
        if result.all_correct?
          puts progress_marker
          puts "\n\n"
        elsif !result.partially_correct?
          @current_question = nil
          puts "Správně:"
          puts question.answer_list
        end

        puts "\n"
      end
    end
  end

  def current_question
    if !@current_question || @current_question.answered_corretly?
      @current_question = random_unanswered_question
    else
      @current_question
    end
  end

  def random_unanswered_question
    unanswered_questions.sample
  end

  def unanswered_questions
    @questions.find_all { |question| !question.answered_corretly? }
  end

  def progress_marker
    question_count = @questions.length
    answered_count = question_count - unanswered_questions.length
    "#{answered_count}/#{@questions.length}"
  end
end

filename = ARGV[0]

fail "Musíte zadat soubor, ze kterého se načtou otázky a odpovědi".colorize(:red) if filename.blank?

questions_and_answers = File.
  read(filename).
  split(/\n/).
  reject { |line| line.blank? }.
  map { |line| line.split(/\t/) }

if ARGV[1].present?
  from = ARGV[1].to_i - 1
  offset = ARGV[2].present? ? ARGV[2].to_i : questions_and_answers.length - from
  questions_and_answers = questions_and_answers[from, offset]
end

Quiz.new(questions_and_answers).run
