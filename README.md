# Bonus: Seeding from an API

## Learning Goals

- Use a web API to seed a database with realistic data

## Introduction

In the last lesson, we learned the importance of having seed data in our
database. We also learned how to generate randomized data using Faker. Sometimes
though, it's preferable to have more realistic data to work with. We could
create that data by hand, but there's also a whole lot of structured data out
there on the internet for us to use.

One other way to get more realistic data into our database is to seed data from
a **JSON API**. There are many public JSON APIs out there that you can use to
access data that other developers have put together on a variety of topics. This
[Public APIs][public apis] repository has a great curated list broken down by
category, so depending on what kind of data you're looking for, you may be able
to find an API here.

For our application, we'll be using the [Dungeons and Dragons API][dnd api] as
an example. This API doesn't require any authorization (no API key is required),
so it's easy to set up.

In this application, we have a migration for one table, `spells`:

```rb
# db/migrate/20210718144445_create_spells.rb
class CreateSpells < ActiveRecord::Migration[6.1]
  def change
    create_table :spells do |t|
      t.string :name
      t.integer :level
      t.string :description
    end
  end
end
```

And a corresponding `Spell` class that inherits from Active Record:

```rb
# app/models/spell
class Spell < ActiveRecord::Base

end
```

This lesson is set up as a code-along, so make sure to fork and clone the
lesson. Then run these commands to set up the dependencies and set up the
database:

```console
$ bundle install
$ bundle exec rake db:migrate
```

## Working with JSON APIs

The first step in working with an API is to understand what **endpoints** it has
available, and how the **response** is structured. For our purposes, we'll be
using the [spells endpoint][] from the [Dungeons and Dragons API][dnd api] to
generate data for a `spells` table in our database.

Based on their documentation, we can see a list of all the spells at this
endpoint: [https://www.dnd5eapi.co/api/spells][spells index], and making a
request to the endpoint for one single spell, like
[https://www.dnd5eapi.co/api/spells/acid-arrow][spells show], will return a JSON
object formatted like this:

```json
{
  "index": "acid-arrow",
  "name": "Acid Arrow",
  "desc": [
    "A shimmering green arrow streaks toward a target within range and bursts in a spray of acid. Make a ranged spell attack against the target. On a hit, the target takes 4d4 acid damage immediately and 2d4 acid damage at the end of its next turn. On a miss, the arrow splashes the target with acid for half as much of the initial damage and no damage at the end of its next turn."
  ],
  "higher_level": [
    "When you cast this spell using a spell slot of 3rd level or higher, the damage (both initial and later) increases by 1d4 for each slot level above 2nd."
  ],
  "range": "90 feet",
  "components": ["V", "S", "M"],
  "material": "Powdered rhubarb leaf and an adder's stomach.",
  "ritual": false,
  "duration": "Instantaneous",
  "concentration": false,
  "casting_time": "1 action",
  "level": 2,
  "attack_type": "ranged"
}
```

[spells index]: https://www.dnd5eapi.co/api/spells
[spells show]: https://www.dnd5eapi.co/api/spells/acid-arrow

So in order to seed our database from this API, we'll need to use Ruby to:

- Make a request to the spells endpoint for the API
- Parse the JSON response into a Ruby hash
- Find the data in that hash that we want to save to our database
- Use Active Record to save the data to the database

### Using Rest Client to Interact with APIs

To make the request to the API in Ruby, we'll use the
[Rest Client][rest-client] gem. This library simplifies the process of making
network requests in Ruby. We've already got this gem in our Gemfile, so let's
experiment with it in our `rake console`:

```rb
response = RestClient.get "https://www.dnd5eapi.co/api/spells/acid-arrow"
# => <RestClient::Response 200 "{\"index\":\"a...">

spell_hash = JSON.parse(response)
# => {"index"=>"acid-arrow",
#  "name"=>"Acid Arrow",
#  "desc"=>
#   ["A shimmering green arrow streaks toward a target within range and bursts in a spray of acid. Make a ranged spell attack against the target. On a hit, the target takes 4d4 acid damage immediately and 2d4 acid damage at the end of its next turn. On a miss, the arrow splashes the target with acid for half as much of the initial damage and no damage at the end of its next turn."], ...

spell_hash["name"]
# => "Acid Arrow"

spell_hash.keys
# spell_hash
# => ["index",
#  "name",
#  "desc",
#  "higher_level",
#  "range",
#  "components",
#  "material", ...
```

Awesome! With just a couple lines of code, we were able to make a GET request to
the API and parse the response into a Ruby hash.

The process of using the Rest Client gem in Ruby should feel similar to using
`fetch` in JavaScript: we make a request using a URL and HTTP verb, which
returns a response object; to work with the response object, we parse it from a
JSON string to a Ruby hash. One key difference is that this code happens
_synchronously_ in Ruby rather than _asynchronously_. Our program has to wait
for the response before running the next line of code.

Once we have the response data as a Ruby hash, we can interact with it like we
would with any other Ruby hash, and access data using bracket notation.

### Using Rest Client from the Seed File

Now that we know how to access the data we need, let's write some Ruby code in
the `seeds.rb` file that will communicate with the API and persist data to our
database. Add this code to the `seeds.rb` file:

```rb
puts "Seeding spells..."
# these are the spells we want to add to the database
spells = ["acid-arrow", "animal-messenger", "calm-emotions", "charm-person"]

# iterate over each spell
spells.each do |spell|
  # make a request to the endpoint for the individual spell:
  response = RestClient.get "https://www.dnd5eapi.co/api/spells/#{spell}"

  # the response will come back as a JSON-formatted string.
  # use JSON.parse to convert this string to a Ruby hash:
  spell_hash = JSON.parse(response)

  # create a spell in the database using the data from this hash:
  Spell.create(
    name: spell_hash["name"],
    level: spell_hash["level"],
    description: spell_hash["desc"][0] # spell_hash["desc"] returns an array, so we need to access the first index to get just a string of the description
  )
end

puts "Done seeding!"
```

As you can see, we're making requests for several different spells from the API,
and using the response to create new records in our `spells` table with Active
Record.

Working with this JSON API and (many others) mean you need to be comfortable
working with Ruby hashes and arrays, since many API developers will structure
their data as nested hashes and arrays. If you're ever unsure how to get the
data out of the response, try using `binding.pry` and experiment in the console.

Now that we've got the new code in the `seeds.rb` file, we can run it:

```console
$ bundle exec rake db:seed
```

And enter `rake console` to explore the new data:

```rb
Spell.last
# => #<Spell:0x00007fee74b38138
#  id: 4,
#  name: "Charm Person",
#  level: 1,
#  description:
#   "You attempt to charm a humanoid you can see within range. It must make a wisdom saving throw, and does so with advantage if you or your companions are fighting it. If it fails the saving throw, it is charmed by you until the spell ends or until you or your companions do anything harmful to it. The charmed creature regards you as a friendly acquaintance. When the spell ends, the creature knows it was charmed by you.">
```

Success! We've taken the data from the API and used it to populate our database.
Run `learn test` now to pass the test and complete this lesson.

## Resources

- [Rest Client][rest-client]
- [Public APIs][public apis]

[rest-client]: https://github.com/rest-client/rest-client
[public apis]: https://github.com/public-apis/public-apis
[dnd api]: http://www.dnd5eapi.co/docs/#intro
[spells endpoint]: http://www.dnd5eapi.co/docs/#spell-section
