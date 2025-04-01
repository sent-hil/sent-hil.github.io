---
layout: post
title: How to test sidekiq_return_in_block?
---

{{ page.title }}
================

<p class="meta">04 May, 2025</p>

Sidekiq allows specifying behavior when there is an exception. You can choose to use the default exponential backoff algorithm. I needed a way to change the backoff to be slower and more random. The exact backoff algorithm can be anything.

```ruby
class YourWorker
  include Sidekiq::Job

  sidekiq_retry_in do |count, exception, jobhash|
    case exception
    when ::Faraday::TooManyRequestsError
      5.minute.to_i + rand(10000)
    end
  end
end
```

I also wanted to test it. Found the simplest way is to just call the block and test that behavior which is what the [author](https://github.com/sidekiq/sidekiq/issues/4104) of Sidekiq recommends.

```ruby
describe "Sidekiq retry in block" do
  subject { YourWorker }

  let(:exception) do
    Faraday::TooManyRequestsError.new("Too many requests")
  end

  it "queues between 5...172 minutes" do
    expect(
      subject.sidekiq_retry_in_block.call(0, exception, {})
    ).to be_between(300, 10300)
  end
end
```
