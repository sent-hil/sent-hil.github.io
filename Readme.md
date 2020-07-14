sent-hil.github.io
------------------

Jekyll blog that powers [sent-hil.com](http://sent-hil.com). This is a fork of the [original repo](https://github.com/mojombo/mojombo.github.io) with some minor modifications.

## New Posts

To create a new empty post do

    go run scripts/new_blog_post.go -title='Title of my New Post'

This'll create a new file in `_posts` prefixed with today's date and title of blog post.

## Dokku

This blog is deployed using [dokku](http://dokku.viewdocs.io/dokku/).

### Setup

    # create new app
    git remote add dokku dokku@sent-hil.com:sent-hil.com
    git push dokku master

    ssh <ip of machine with dokku>

    dokku domains:set-global sent-hil.com
    dokku config:set sent-hil.com NGINX_ROOT=_site

    # setup https
    dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
    dokku config:set --no-restart myapp DOKKU_LETSENCRYPT_EMAIL=your@email.tld
    dokku letsencrypt sent-hil.com

### .git/hooks/pre-commit

This pre-commit script will build jekyll and add the built files to the commit. It makes commit a tad bit slow, but worth it.

```
#!/bin/sh

jekyll build
git add _site
```

### Deploy

    git push dokku master

License
-------
`_posts` directory is copyright of Senthil Arivudainambi. You may not reuse anything therein without my permission.

All other directories and files are MIT Licensed. This is the same license of the original repo: https://github.com/mojombo/mojombo.github.io
