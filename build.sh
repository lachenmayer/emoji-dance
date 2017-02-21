#!/bin/bash
elm-make Dance.elm --output public/index.html &&
docker build -t emoji-dance .
