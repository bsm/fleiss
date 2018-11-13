# Fleiss

[![Build Status](https://travis-ci.org/bsm/fleiss.png?branch=master)](https://travis-ci.org/bsm/fleiss)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Minimialist background jobs backed by ActiveJob and ActiveRecord.

## Usage

Define your active jobs, as usual:

```ruby
class SimpleJob < ActiveJob::Base
  queue_as :default

  def perform(*args)
    # Perform Job
  end
end
```

Allow jobs to expire job by specifying an optional TTL:

```ruby
class ExpringJob < ActiveJob::Base
  queue_as :default
  retry_on SomeError, attempts: 1_000_000

  def perform(*args)
    # Perform Job
  end

  # This will cause the job to retry up-to 1M times
  # until the 72h TTL is reached.
  def ttl
    72.hours
  end
end
```

Include the data migration:

```ruby
# db/migrate/20182412102030_create_fleiss_jobs.rb
require 'fleiss/backend/active_record/migration'

class CreateFleissJobs < ActiveRecord::Migration[5.2]
  def up
    Fleiss::Backend::ActiveRecord::Migration.migrate(:up)
  end

  def down
    Fleiss::Backend::ActiveRecord::Migration.migrate(:down)
  end
end
```

Run the worker:

```ruby
bundle exec fleiss -I . -r config/environment
```
