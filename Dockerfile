FROM node

WORKDIR /app/
EXPOSE 1337

COPY ./package.json /app/
RUN cd /app; npm install

COPY ./server.js /app/
COPY ./lib/* /app/lib/
COPY ./public/* /app/public/

CMD ["node", "server.js"]
