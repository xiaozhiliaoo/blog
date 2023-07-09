#!/usr/bin/env bash

hexo clean

git add -A && git commit -m "up" && git push
