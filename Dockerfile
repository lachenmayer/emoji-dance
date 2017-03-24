FROM node

WORKDIR /app/
EXPOSE 1337

COPY ./Dance.elm /app/
COPY ./server.js /app/
COPY ./lib/* /app/lib/
COPY ./package.json /app/
RUN mkdir /app/public

RUN npm install
RUN npm run build

CMD ["node", "server.js"]
