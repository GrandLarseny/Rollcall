module Lita
  module Handlers
    class RollcallRobot < Handler
      # insert handler code here
      require 'firebase'
      require 'date'

      route(/^yo,\s*(.+)/i, :echo, command: true)
      route(/^echo\s+(.+)/, :echo, command: true, help: {
        "echo TEXT" => "Replies back with TEXT."
      })

      route(/^help$/, :helpMe, command: true, help: "List out all the great things about Rollcall! That this!")
      route(/^what *it *do$/, :helpMe, command: true)
      route(/^halp$/, :helpMe, command: true)

      route(/(t|today|y|yesterday|b|blocker|blocked by) *[-:]\s*/i, :standup, command: true)

      route(/^callout/i, :replyRollcall, command: true)
      route(/^list/i, :replyRollcall, command: true)

      route(/^remove/i, :removeLast, command: true)
      route(/^belay/i, :removeLast, command: true)
      route(/^i (have )?regret/i, :removeLast, command: true)
      route(/^nonono/i, :removeLast, command: true)

      def firebaseRef
        base_uri = 'https://br-rollcall.firebaseio.com/'
        firebase = Firebase::Client.new(base_uri)
      end

      def helpMe(response)
        helpText = "Hello, @#{response.user.mention_name}! I'm Rollcall, a chatbot designed to help you keep track of the daily standup. There are a handful of things you can do. You can add a standup status, remove the latest status, or list all the standups for day.

To add a status, just format it with today's status, yesterday's status, and any blockers if applicable. All three are optional.
For example, `@Rollcall Yesterday: Worked on the test scripts. Today: Testing out the capacitor. Blocker: Rain.`

To remove a status, just tell me to remove the last status.
For example, `@Rollcall remove`

And to display the statuses, just tell me to list them out.
For example, `@Rollcall list`"
        response.reply(helpText)
      end

      def echo(response)
        response.reply(response.matches)
      end

      def standup(response)
        today = nil
        yesterday = nil
        blockers = nil
        
        puts "DDL: Running standup for: #{response.message.body}"
        results = response.message.body.split(/(t|today|y|yesterday|b|blocker) *[-:]\s*/i)

        results.each_index do |mi|
          argu = results[mi]
          puts "DDL: -- Matching #{argu}"
          if argu.match(/^t(oday)?/i)
            today = results[mi + 1]
          end
          if argu.match(/^y(esterday)?/i)
            yesterday = results[mi + 1]
          end
          if argu.match(/^b(locker)?/i)
            blockers = results[mi + 1]
          end
        end

        puts "DDL: Calling standup for today - #{today}"
        addStandup(response, today, yesterday, blockers)

        response.reply("Copy that, @#{response.user.mention_name}!")
      end

      def addStandup(response, today, yesterday, blockers)
        firebase = firebaseRef()

        date = Date.today.to_s

        firebase.push("standups", { :user => response.user.mention_name, :room => response.room.id, :date => date, :today => today, :yesterday => yesterday, :blockers => blockers, :timestamp => Time.now.to_i })
      end

      def replyRollcall(response)
        rollcall = ""

        standups = toadysStandups(response.room.id)
        standups.each do |key, value|
          puts "DDL: --- rollcall #{value}"

          puts "DDL: --- value.user = #{value['user']}"
          rollcall = "@#{value["user"]} "

          if value["today"] && !value["today"].empty?
            rollcall += "*Today:* #{value["today"]} "
          end
          if value["yesterday"] && !value["yesterday"].empty?
            rollcall += "*Yesterday:* #{value["yesterday"]} "
          end
          if value["blockers"] && !value["blockers"].empty?
            rollcall += "*Blockers:* _#{value["blockers"]}_ "
          end

          response.reply(rollcall)
        end
        
        if rollcall.empty?
          response.reply("_[tumbleweeds roll]_ Pretty empty around here. No one's reported in yet.")
        end
      end

      def removeLast(response)
        standups = toadysStandups(response.room.id)
        myStandups = standups.select { |key, standup| standup["user"] = response.user.mention_name }
        lastStandup = myStandups.max_by { |k, standup| standup["timestamp"] }
        puts "DDL: Removing standup #{lastStandup[0]}"

        if lastStandup.nil || lastStandup.empty?
          response.reply("Today is clear @#{response.user.mention_name}, no worries")
          return
        end

        firebase = firebaseRef()
        firebase.delete("standups/#{lastStandup[0]}")

        response.reply("Forget it ever happened, @#{response.user.mention_name}")
      end

      def toadysStandups(room)
        firebase = firebaseRef()
        rollcallResponse = firebase.get("standups", "orderBy=\"room\"&equalTo=\"#{room}\"")
        puts "DDL: Found standups #{rollcallResponse.raw_body}"

        date = Date.today.to_s

        rollcallResponse.body.select { |key, standup| standup["date"] == date }
      end

      Lita.register_handler(self)
    end
  end
end
