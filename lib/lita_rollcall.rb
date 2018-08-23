module Lita
  module Handlers
    Help.routes.pop

    class RollcallRobot < Handler
      require 'firebase'
      require 'date'
      require_relative './standups'

      def initialize()
        @service = Rollcall::Service.new()
      end

      route(/^yo,\s*(.+)/i, :echo, command: true)
      route(/^echo\s+(.+)/, :echo, command: true, help: {
        "echo TEXT" => "Replies back with TEXT."
      })

      route(/^help$/, :helpMe, command: true)
      route(/^what *it *do$/, :helpMe, command: true)
      route(/^halp$/, :helpMe, command: true)
      route(/^secret help$/, :verboseHelpMe, command: true)

      route(/ (t|today|y|yesterday|b|blocker|blocked by) *[-:]\s*/i, :standup, command: true) # We need the standup portion to be preceeded by a space
      route(/^(t|today|y|yesterday|b|blocker|blocked by) *[-:]\s*/i, :standup, command: true) # Unless it's the very first item

      route(/^print/i, :replyRollcall, command: true)
      route(/^rollcall/i, :replyRollcall, command: true)
      route(/^callout/i, :replyRollcall, command: true)
      route(/^list/i, :replyRollcall, command: true)
      route(/^log/i, :replyRollcall, command: true)

      route(/^remove/i, :removeLast, command: true)
      route(/^belay/i, :removeLast, command: true)
      route(/^i (have )?regret/i, :removeLast, command: true)
      route(/^nonono/i, :removeLast, command: true)

      on(:unhandled_message) do |payload|
        message = payload[:message]

        if message && message.command?
          puts "DDL: Default command with body #{message.body}"
          newStandup = Rollcall::Standup.new(message.user.mention_name, message.room_object.id, message.body)
          @service.addStandup(newStandup)

          message.reply_privately("Recorded your standup, @#{message.user.mention_name} _If that isn't what you meant, you can remove the recorded status_")
        end
      end

      def helpMe(response)
        bot_name = "standup-bot"
      
        help_text = "Hello, @#{response.user.mention_name}! I'm #{bot_name}, a chatbot designed to help you keep track of the daily standup. There are a handful of things you can do. You can add a standup status, remove the latest status, or list all the standups for day.

To add a status, just format it with today's status, yesterday's status, and any blockers if applicable. All three are optional.
For example, `@#{bot_name} Yesterday: Worked on the test scripts. Today: Testing out the capacitor. Blocker: Rain.`

To remove a status, just tell me to remove the last status.
For example, `@#{bot_name} remove`

And to display the statuses, just tell me to list them out.
For example, `@#{bot_name} list`

For the very curious, you can try `@#{bot_name} secret help`"
        response.reply(help_text)
      end

      def verboseHelpMe(response)
        help_text = "Wow, you totally hacked the system and found the secret stash of all my commands! You are the best hacker ever, the Gibson is no match for you.

So, when you're typing out a new standup, you can use the any of the following to start the Today, Yesterday or Blocker sections, and upper/lowercase does not matter:
```T:
T -
Today:
Today-
Y:
Y -
Yesterday:
B:
Blocker:```
...etc. Basically anything that's the word or first letter followed by a colon (:) or dash (-)

When you want to list out all the standups for a room, you can start a command with any of the following:
```print
rollcall
callout
list
log```

And when you want to remove a standup, you can start you command with any of the following
```remove
belay
i regret
i have regrets
nonono```

That's about it! Great pwning!
"

        response.reply(help_text)
      end

      def echo(response)
        response.reply(response.matches)
      end

      def standup(response)
        newStandup = Rollcall::Standup.new(response.user.mention_name, response.room.id, " #{response.message.body}")

        @service.addStandup(newStandup)

        response.reply("Copy that, @#{response.user.mention_name}!")
      end

      def replyRollcall(response)
        rollcall = ""

        standups = @service.toadysStandups(response.room.id)
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
        response.reply(@service.removeLast(response.user.mention_name, response.room.id))
      end

      Lita.register_handler(self)
    end
  end
end
