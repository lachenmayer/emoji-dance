FROM node

WORKDIR /app/
EXPOSE 1337

COPY ./package.json /app/
RUN cd /app; npm install

RUN npm build

COPY ./server.js /app/
COPY ./lib/* /app/lib/

CMD ["node", "server.js"]
