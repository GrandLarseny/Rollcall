module Rollcall
  class Standup
    attr_reader :user, :room, :preamble, :today, :yesterday, :blockers

    def initialize(user, room, message) 
      @user = user
      @room = room

      @today = nil
      @yesterday = nil
      @blockers = nil
      @preamble = nil

      message = " #{message}"

      puts "DDL: Creating standup for: #{message}"
      results = message.split(/ (t|today|y|yesterday|b|blocker|blocked by) *[-:]\s*/i)
      puts results

      if !results || results.empty? || results.count == 1
        @today = message.strip
        return
      end

      @preamble = results[0].strip
      results.each_index do |mi|
        next if !results[mi].match(/^(t|today|y|yesterday|b|blocker|blocked by)$/i)

        argu = results[mi]
        puts "DDL: -- Matching #{argu}"
        if argu.match(/^t(oday)?/i)
          @today = results[mi + 1].strip
          @preamble = "" if mi == 0
        end
        if argu.match(/^y(esterday)?/i)
          @yesterday = results[mi + 1].strip
          @preamble = "" if mi == 0
        end
        if argu.match(/^(b|blocker|blocked by)/i)
          @blockers = results[mi + 1].strip
          @preamble = "" if mi == 0
        end 
      end
    end
  end

  class Service
    require 'firebase'
    require 'date'

    def initialize()
      @firebase = Firebase::Client.new('https://br-rollcall.firebaseio.com/')
    end

    def addStandup(standup)
      date = Date.today.to_s

      @firebase.push("standups", { :user => standup.user, :room => standup.room, :date => date, :preamble => standup.preamble, :today => standup.today, :yesterday => standup.yesterday, :blockers => standup.blockers, :timestamp => Time.now.to_i })
    end

    def removeLast(user, room, mention_name)
      standups = toadysStandups(room)
      myStandups = standups.select { |key, standup| standup["user"] = user }
      lastStandup = myStandups.max_by { |k, standup| standup["timestamp"] }

      if !lastStandup || lastStandup.empty? || lastStandup.length <= 0
        return "Today is clear @#{mention_name}, no worries"
      end

      puts "DDL: Removing standup #{lastStandup[0]}"
      @firebase.delete("standups/#{lastStandup[0]}")

      "Forget it ever happened, @#{mention_name}"
    end


    def toadysStandups(room)
      rollcall_response = @firebase.get("standups", "orderBy=\"room\"&equalTo=\"#{room}\"")

      date = Date.today.to_s

      rollcall_response.body.select { |key, standup| standup["date"] == date }
    end

  end
end
