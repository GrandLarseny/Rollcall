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

      route(/(t|today|y|yesterday|b|blocker) *[-:]\s*/i, :standup, command: true)

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

        firebase.push("standups", { :user => response.user.mention_name, :room => response.room.id, :date => date, :today => today, :yesterday => yesterday, :blockers => blockers })
      end


      def replyRollcall(response)
        firebase = firebaseRef()
        rollcallResponse = firebase.get("standups", "orderBy=\"room\"&equalTo=\"#{response.room.id}\"")
        puts "DDL: Found standups #{rollcallResponse.raw_body}"

        date = Date.today.to_s
        standups = rollcallResponse.body.select { |key, standup| standup["date"] == date }

        rollcall = ""
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
          response.reply("_tumbleweeds roll_ Pretty empty around here. No one's reported in yet.")
        end
    end

    def removeLast(response)
      firebase = firebaseRef()

    end

    Lita.register_handler(self)
    end
  end
end
