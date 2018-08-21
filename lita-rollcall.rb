module Lita
  module Handlers
    class RollcallStatus

    end

    class RollcallRobot < Handler
      require 'firebase'
      require 'date'

      route(/^yo,\s*(.+)/i, :echo, command: true)
      route(/^echo\s+(.+)/, :echo, command: true, help: {
        "echo TEXT" => "Replies back with TEXT."
      })

      route(/^help$/, :helpMe, command: true)
      route(/^what *it *do$/, :helpMe, command: true)
      route(/^halp$/, :helpMe, command: true)

      route(/(t|today|y|yesterday|b|blocker|blocked by) *[-:]\s*/i, :standup, command: true)

      route(/^print/i, :replyRollcall, command: true)
      route(/^rollcall/i, :replyRollcall, command: true)
      route(/^callout/i, :replyRollcall, command: true)
      route(/^list/i, :replyRollcall, command: true)

      route(/^remove/i, :removeLast, command: true)
      route(/^belay/i, :removeLast, command: true)
      route(/^i (have )?regret/i, :removeLast, command: true)
      route(/^nonono/i, :removeLast, command: true)

      on(:unhandled_message) do |payload|
        message = payload[:message]

        if message && message.command?
          puts "DDL: Unhandled message with message #{message}"
          addStandup(message.user.mention_name, message.room_object.id, "", message.body, "", "")

          message.reply("Recorded your standup, @#{message.user.mention_name} _If that isn't what you meant, you can remove the recorded status_")
        end
      end

      def firebaseRef
        base_uri = 'https://br-rollcall.firebaseio.com/'
        firebase = Firebase::Client.new(base_uri)
      end

      def helpMe(response)
        helpText = "Hello, @#{response.user.mention_name}! I'm Standupbot, a chatbot designed to help you keep track of the daily standup. There are a handful of things you can do. You can add a standup status, remove the latest status, or list all the standups for day.

To add a status, just format it with today's status, yesterday's status, and any blockers if applicable. All three are optional.
For example, `@Standupbot Yesterday: Worked on the test scripts. Today: Testing out the capacitor. Blocker: Rain.`

To remove a status, just tell me to remove the last status.
For example, `@Standupbot remove`

And to display the statuses, just tell me to list them out.
For example, `@Standupbot list`"
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
        results = response.message.body.split(/(t|today|y|yesterday|b|blocker|blocked by) *[-:]\s*/i)

        if !results || results.empty?
          response.reply("Is this thing on? I didn't see anything there to record as a standup")
          return
        end

        preamble = results[0]
        results.each_index do |mi|
          argu = results[mi]
          puts "DDL: -- Matching #{argu}"
          if argu.match(/^t(oday)?/i)
            today = results[mi + 1]
            if mi == 0
              preamble = ""
            end
          end
          if argu.match(/^y(esterday)?/i)
            yesterday = results[mi + 1]
            if mi == 0
              preamble = ""
            end
          end
          if argu.match(/^b(locker)?/i)
            blockers = results[mi + 1]
            if mi == 0
              preamble = ""
            end
          end
        end

        puts "DDL: Calling standup for today - #{today}"
        addStandup(response.user.mention_name, response.room.id, preamble, today, yesterday, blockers)

        response.reply("Copy that, @#{response.user.mention_name}!")
      end

      def addStandup(user, room, preamble, today, yesterday, blockers)
        firebase = firebaseRef()

        date = Date.today.to_s

        firebase.push("standups", { :user => user, :room => room, :date => date, :preamble => preamble, :today => today, :yesterday => yesterday, :blockers => blockers, :timestamp => Time.now.to_i })
      end

      def replyRollcall(response)
        rollcall = ""

        standups = toadysStandups(response.room.id)
        standups.each do |key, value|
          puts "DDL: --- rollcall #{value}"

          puts "DDL: --- value.user = #{value['user']}"
          rollcall = "@#{value["user"]} "

          if value["preamble"] && !value["preamble"].empty?
            rollcall += "#{value["preamble"]} "
          end
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

        blockers = standups.select { |key, standup| standup["blockers"] && !standup["blockers"].empty? }
        if blockers && !blockers.empty?
          rollcall = "*_All Blockers_*\n"
          blockers.each do |key, value|
            rollcall += "@#{value["user"]} "

            if value["preamble"] && !value["preamble"].empty?
              rollcall += "#{value["preamble"]} "
            end
            rollcall += "*Blockers:* #{value["blockers"]}\n"
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

        if !lastStandup || lastStandup.empty? || lastStandup.length <= 0
          response.reply("Today is clear @#{response.user.mention_name}, no worries")
          return
        end

        puts "DDL: Removing standup #{lastStandup[0]}"
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
