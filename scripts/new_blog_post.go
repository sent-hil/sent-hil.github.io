package main

import (
	"flag"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"strings"
	"time"
)

var (
	blogTemplate = `---
layout: post
title: %s
---

{{ page.title }}
================

<p class="meta">%s</p>
`

	title = flag.String("title", "", "Title of blog post")
	date  = time.Now().Format("2006-01-02")

	// blogPath is home relative path to blog posts
	blogPath = "play/sent-hil.github.io/_posts"
)

func main() {
	flag.Parse()

	if *title == "" {
		panic("Title cannot be empty")
	}

	if err := createPost(*title); err != nil {
		panic(err)
	}
}

// createPost creates post with given title (after it's transformed) if a post
// with same name already doesn't exists
func createPost(title string) error {
	blogPath, err := getBlogPath()
	if err != nil {
		return err
	}

	t := parameterize(filepath.Join(blogPath, title))
	if _, err = os.Stat(t); os.IsExist(err) {
		return fmt.Errorf("File: %s with title already exists", t)
	}

	file, err := os.Create(t)
	if err != nil {
		return err
	}

	defer file.Close()

	_, err = file.WriteString(fmt.Sprintf(blogTemplate, titleize(title), date))
	return err
}

// getBlogPath returns full path to blog directory
func getBlogPath() (string, error) {
	u, err := user.Current()
	if err != nil {
		return "", err
	}

	p := filepath.Join(u.HomeDir, blogPath)
	if _, err := os.Open(filepath.Join(u.HomeDir, blogPath)); err != nil {
		return "", err
	}

	return p, nil
}

// titleize splits given string on spaces on uppercase the 1st char and
// lowercases the rest of chars and join them
func titleize(str string) (title string) {
	for _, str := range strings.Split(str, " ") {
		title += strings.ToUpper(string(str[0]))
		title += strings.ToLower(string(str[1:]))
		title += " "
	}

	return title
}

// parameterize splits string on spaces and joins them with `-`
func parameterize(str string) string {
	return strings.Join(strings.Split(str, " "), "-")
}
