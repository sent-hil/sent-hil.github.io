---
layout: post
title: How do Rails/Golang/Python handle canceling a HTTP request mid transaction?
---

{{ page.title }}
================

<p class="meta">20 Jul, 2025</p>

Earlier today I saw this [tweet](https://x.com/hnasr/status/1946933331611795609):

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">I enjoy asking this question during interviews, as it opens the door to a wide array of engaging technical discussions. It also shines light at the parts of the system that were assumed to be understood. <br><br>How would you handle the cancellation of an HTTP request that started a…</p>&mdash; Hussein Nasser (@hnasr) <a href="https://twitter.com/hnasr/status/1946933331611795609?ref_src=twsrc%5Etfw">July 20, 2025</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

My first thought was the webserver (at my day job it would be Rails/Puma) would cancel the transaction, so nothing gets committed, but then I remembered, especially in local env, a long running transaction would block even after closing the browser.

To test it live I asked Claude Code to generate a 1 file Rails script which mimicked a long running transaction by doing [sleep](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-DELAY) in postgres before committing a record. If I canceled the request while pg is sleeping and if Rails cancels the transaction when request is canceled, then no record should be committed.

## Testing Rails

I asked Claude Code to use `uni_rails`, which is a library to create Rails apps in just a single file, making it's easier to read.

```ruby
#... setup code, see https://github.com/sent-hil/http-connection-cancel-experiments/blob/main/main.rb for full file

class PagesController < ActionController::Base
  def index
    puts "Starting long-running operation at #{Time.now}"

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SELECT pg_sleep(5);")
      record = ExperimentRecord.create!(message: "Operation completed at #{Time.now}")
      puts "Record created with ID: #{record.id} at #{Time.now}"
    end

    puts "Response stream closed before render attempt: #{response.stream.closed?} at #{Time.now}"

    begin
      render plain: "Long operation completed successfully at #{Time.now}"
      puts "Successfully sent response to client at #{Time.now}"
    rescue => e
      puts "Failed to send response - client likely disconnected: #{e.class} - #{e.message} at #{Time.now}"
    end
  end
end

UniRails.run(Port: 3003)
```

Ran it with `ruby main.rb` to start the server and in another terminal ran `http localhost:3000` and canceled it <1sec. Just as suspected I saw:

```ruby
Starting long-running operation at 2025-07-20 19:02:48 -0700
Record created with ID: 10 at 2025-07-20 19:02:53 -0700
Response stream closed before render attempt: false at 2025-07-20 19:02:53 -0700
```

This indicates Rails does not automatically cancel the transaction if the client cancels the HTTP request before the transaction ends.

## Testing Go

This is not the default behavior In Go. When using the `net/http` package you have access to `context.Context` which you can pass to `database/sql` db connection. When this `context` closes prematurely, the database will abort the transaction right away. Once again I asked Claude code to generate me a simple Go app to showcase this behavior:

```golang
package main

import (
    // ...
)

func main() {
    // setup code, see https://github.com/sent-hil/http-connection-cancel-experiments/blob/main/main.go for full code
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		log.Printf("Starting long-running operation at %v", time.Now())

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			log.Printf("Failed to begin transaction: %v", err)
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}
		defer tx.Rollback() // Will be a no-op if we commit successfully

		_, err = tx.ExecContext(ctx, "SELECT pg_sleep(5)")
		if err != nil {
			log.Printf("Sleep was interrupted: %v at %v", err, time.Now())
			return
		}

		var recordID int
		err = tx.QueryRowContext(ctx, `
			INSERT INTO experiment_records (message)
			VALUES ($1)
			RETURNING id
		`, fmt.Sprintf("Operation completed at %v", time.Now())).Scan(&recordID)

		if err != nil {
			log.Printf("Failed to insert record: %v at %v", err, time.Now())
			return
		}

		err = tx.Commit()
		if err != nil {
			log.Printf("Failed to commit transaction: %v at %v", err, time.Now())
			return
		}

		log.Printf("Record created with ID: %d at %v", recordID, time.Now())

		fmt.Fprintf(w, "Long operation completed successfully at %v\n", time.Now())
	})

	log.Println("Starting server on :3003")
	log.Fatal(http.ListenAndServe(":3003", nil))
}
```

This is what I see when I run `go run main.go` in one terminal and `http localhost:3003` in another and canceling the request in <1s.

```
2025/07/20 19:27:38 Starting long-running operation at 2025-07-20 19:27:38.452558 -0700 PDT m=+1.313060460
2025/07/20 19:27:38 Sleep was interrupted: pq: canceling statement due to user request at 2025-07-20 19:27:38.809391 -0700 PDT m=+1.669896835
```

Just to confirm I checked the db with psql and as expected with Go, no record was created.

Looking at the Go `database/sql` source code, [this](https://cs.opensource.google/go/go/+/refs/tags/go1.24.5:src/database/sql/sql.go;l=2212) seems to be place where the behavior is defined:

#### Source code of behavior in Go

```golang
// awaitDone blocks until the context in Tx is canceled and rolls back
// the transaction if it's not already done.
func (tx *Tx) awaitDone() {
	// Wait for either the transaction to be committed or rolled
	// back, or for the associated context to be closed.
	<-tx.ctx.Done()

	// Discard and close the connection used to ensure the
	// transaction is closed and the resources are released.  This
	// rollback does nothing if the transaction has already been
	// committed or rolled back.
	// Do not discard the connection if the connection knows
	// how to reset the session.
	discardConnection := !tx.keepConnOnRollback
	tx.rollback(discardConnection)
}
```

I did the same thing with Python/FastAPI and it seems to have the same behavior as Rails. All the above code is available [here](https://github.com/sent-hil/http-connection-cancel-experiments), including `main.py` which shows the Python example. NOTE, when I first asked Claude Code to generate the files, it did this weird thing were it checked if connection was closed in between the sleep and insert lines in transaction which is not the behavior I wanted to test.

### Closing thoughts

Generating throwaway code for quick experiments/prototypes is an excellent use case for LLMs. I wouldn't have been able to do the above tests if it wasn't for LLMs. It took about couple hours spread out throughout a sunday while taking care of a baby and doing chores. I don't care about the quality of the code generated, just wanted to test out something real fast. That said the first LLM generated code was incorrect and I wouldn't have known if I hadn't read the code, so maybe there's hope for developers after all.
