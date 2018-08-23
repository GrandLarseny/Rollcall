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

      if !results || results.empty? || results.count == 1
        @today = message
        return
      end

      @preamble = results[0].strip
      results.each_index do |mi|
        next if !results[mi].match(/^(t|today|y|yesterday|b|blocker)$/i)

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
        if argu.match(/^b(locker)?/i)
          @blockers = results[mi + 1].strip
          @preamble = "" if mi == 0
        end 
      end
    end
  end

  class Service
    require 'firebase'
    require 'date'

    @firebase = Firebase::Client.new('https://br-rollcall.firebaseio.com/')

    def addStandup(standup)
      firebase = firebaseRef()

      date = Date.today.to_s

      @firebase.push("standups", { :user => standup.user, :room => standup.room, :date => date, :preamble => standup.preamble, :today => standup.today, :yesterday => standup.yesterday, :blockers => standup.blockers, :timestamp => Time.now.to_i })
    end

    def removeLast(user, room)
      standups = toadysStandups(room)
      myStandups = standups.select { |key, standup| standup["user"] = user }
      lastStandup = myStandups.max_by { |k, standup| standup["timestamp"] }

      if !lastStandup || lastStandup.empty? || lastStandup.length <= 0
        return "Today is clear @#{response.user.mention_name}, no worries"
      end

      puts "DDL: Removing standup #{lastStandup[0]}"
      @firebase.delete("standups/#{lastStandup[0]}")

      "Forget it ever happened, @#{response.user.mention_name}"
    end


    def toadysStandups(room)
      rollcall_response = @firebase.get("standups", "orderBy=\"room\"&equalTo=\"#{room}\"")
      puts "DDL: Found standups #{rollcall_response.raw_body}"

      date = Date.today.to_s

      rollcall_response.body.select { |key, standup| standup["date"] == date }
    end

  end
end