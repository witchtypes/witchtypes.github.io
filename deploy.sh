#!/bin/bash
stack build
stack exec site rebuild

git fetch --all

git checkout -B main --track origin/main

git add -A
git commit -m "publish"

git push origin main:main