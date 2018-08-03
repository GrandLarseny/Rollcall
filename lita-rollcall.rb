module Lita
  module Handlers
    class Standup < Handler
      # insert handler code here
      require 'firebase'
      require 'date'

      route(/^echo\s+(.+)/, :echo, command: true, help: {
        "echo TEXT" => "Replies back with TEXT."
      })

      route(/^points\s?(.*)/, :points, command: true, help: {
        "points" => "prints points for given month"
      })

      route(/^yo,\s*(.+)/, :echo, command: true)
      
      route(/^(.+) did ([^ ]+) (value [^ ]+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (value [^ ]+) (on [^ ]+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (value [^ ]+) (btw .+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (value [^ ]+) (on [^ ]+) (btw .+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (on [^ ]+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (on [^ ]+) (btw .+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (on [^ ]+) (value [^ ]+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (on [^ ]+) (value [^ ]+) (btw .+)$/, :event, command: true)
      route(/^(.+) did ([^ ]+) (btw .+)$/, :event, command: true)

      route(/^(.+) did ([^ ]+)$/, :event, command: true, help: {
        "@mention did task" => "Records that someone did a thing"
      })

      route(/^\s*list ([^ ]+)\s*$/, :list, command: true, help: {
        "list [users|tasks|events]" => "lists all available [users|tasks|events]"
      })

      route(/^\s*feature (.+)$/, :feature, command: true, help: {
        "feature" => "create a feature request"
      })

      def echo(response)
        response.reply(response.matches)
      end

      def feature(response)
        base_uri = 'https://br-rollcall.firebaseio.com/'
        firebase = Firebase::Client.new(base_uri)
        response.reply(response.user.name + "(" + response.user.mention_name + ") requested feature " + response.matches[0][0])
	firebaseResponse = firebase.push("requests", { :user => response.user.mention_name, :feature => response.matches[0][0], :timestamp => {:'.sv' => "timestamp"}})
      end

      def points(response)

        month = Date.parse(response.matches[0][0]) rescue Date.parse(Date.today.strftime("%Y-%m-01"))

        if month != nil
          response.reply("for month: #{month}")
        end

        base_uri = 'https://br-rollcall.firebaseio.com/'
        firebase = Firebase::Client.new(base_uri)
        firebaseResponse = firebase.get("users")
        scores = { }
        firebaseResponse.body.each do |key, array|
            points = firebase.get("events", "orderBy=\"user\"&equalTo=\"#{key}\"")
            score = 0
            points.body.each do |key, array|
              eventDate = Date.parse(array["date"]) rescue nil
              if eventDate >= month && eventDate < month.next_month
                score += array["value"]
              end
            end
            if score > 0
              user = User.find_by_mention_name(key).name
              scores[user] = score
            end
        end
        scores.sort_by { |name, score| score }.reverse! .each do |key, value|
              response.reply("#{key} = #{value}")
        end
      end

      def event(response)
        date = nil
        note = nil
        value = nil
        reply = "#{response.matches[0][0]} did #{response.matches[0][1]}"
        response.matches[0].each do |argu|
          if argu.match(/^value /)
            value = number_or_nil(argu[6..-1])
            reply = reply + " value #{value}"
          end
           if argu.match(/^on /)
            date = Date.parse(argu[3..-1]) rescue Date.parse(Date.today.strftime("%Y-%m-%d"))
            reply = reply + " on #{date}"
          end
          
          if argu.match(/^btw /)
            note = argu[4..-1]
            reply = reply + " btw #{note}"
          end
        end
        response.reply(reply)
        addEvent(response, response.matches[0][0], response.matches[0][1], note, date, value)
      end

      def number_or_nil(string)
        num = string.to_i
        num if num.to_s == string
      end

      def addEvent(response, users, task_alias, note=nil, date=nil, value=nil)
        base_uri = 'https://br-rollcall.firebaseio.com/'
        firebase = Firebase::Client.new(base_uri)
        taskresponse = firebase.get("tasks", "orderBy=\"alias\"&equalTo=\"#{task_alias}\"")
        puts(taskresponse.body.keys[0])
        task = taskresponse.body.values[0]
	      if date==nil
	         date = Date.today.to_s
	      end
              if value==nil
                 customValue = false
                 value = task["value"]
              else
                 customValue = true
              end
              users.split(" ").each do |atuser|
                user = atuser[1..-1]
                userresponse = firebase.get("users", "orderBy=\"$key\"&equalTo=\"#{user}\"")
                if userresponse.body.keys.count < 1
                  response.reply("User #{user} not found")
                end
                jedi = userresponse.body.values[0]["jedi"]
                if jedi != nil
	          firebaseResponse = firebase.push("events", { :user => jedi, :padawan => user.strip, :task => taskresponse.body.keys[0], :value => value/2.0, :date => date, :note => note, :description => task["description"], :customValue => customValue, :timestamp => {:'.sv' => "timestamp"}})
                end
	        firebaseResponse = firebase.push("events", { :user => user.strip, :task => taskresponse.body.keys[0], :value => value, :date => date, :note => note, :description => task["description"], :customValue => customValue, :timestamp => {:'.sv' => "timestamp"}})
              end
      end

      def list(response)
        base_uri = 'https://br-rollcall.firebaseio.com/'
        firebase = Firebase::Client.new(base_uri)
        nani = response.matches[0][0].strip
        firebaseResponse = firebase.get(nani)
        puts(firebaseResponse.body)
        firebaseResponse.body.each do |key, array|
          if nani.match(/^tasks$/)
            task_alias = array["alias"]
            value = array["value"]
            description = array["description"]
            response.reply("#{task_alias} (#{value}) - #{description}")
          end
          if nani.match(/^users$/)
            mention = key
            name = array["name"]
            rank = array["rank"]
            response.reply("#{name} (#{mention}) - #{rank}")
          end
          if nani.match(/^events$/)
            date = array["date"]
            user = array["user"]
            description = array["description"]
            value = array["value"]
            response.reply("On #{date} #{user} did #{description} for #{value} points")
          end
          if nani.match(/^requests$/)
            user = array["user"]
            feature = array["feature"]
            response.reply("#{user} requested #{feature}")
          end
        end
     end

      Lita.register_handler(self)
    end
  end
end
