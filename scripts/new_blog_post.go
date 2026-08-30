package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var (
	blogTemplate = `---
layout: post
title: %s
---

`

	title = flag.String("title", "", "Title of blog post")
	date  = time.Now().Format("2006-01-02")

	// blogPath is home relative path to blog posts
	blogPath = "_posts"

	extension = "md"
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

	titleWithDate := fmt.Sprintf("%s-%s.%s", date, title, extension)

	t := parameterize(filepath.Join(blogPath, titleWithDate))
	if _, err = os.Stat(t); os.IsExist(err) {
		return fmt.Errorf("File: %s with title already exists", t)
	}

	file, err := os.Create(t)
	if err != nil {
		return err
	}

	defer file.Close()

	_, err = file.WriteString(fmt.Sprintf(blogTemplate, titleize(title)))
	return err
}

// getBlogPath returns full path to blog directory
func getBlogPath() (string, error) {
	pwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	p := filepath.Join(pwd, blogPath)
	if _, err := os.Open(p); err != nil {
		return "", err
	}

	return p, nil
}

// titleize uppercases the first character of each word and leaves the rest as
// typed, so ModernBERT and LaTeX-OCR survive rather than becoming Modernbert
// and Latex-ocr.
func titleize(str string) (title string) {
	titles := []string{}
	for _, word := range strings.Split(str, " ") {
		if word == "" {
			titles = append(titles, word)
			continue
		}

		titles = append(titles, strings.ToUpper(word[:1])+word[1:])
	}

	return strings.Join(titles, " ")
}

// parameterize splits string on spaces and joins them with `-`
func parameterize(str string) string {
	splitStr := strings.Split(str, " ")
	for i, s := range splitStr {
		splitStr[i] = strings.ToLower(s)
	}

	return strings.Join(splitStr, "-")
}
