FROM node

WORKDIR /app/
EXPOSE 1337

COPY ./* /app/
RUN mkdir /app/public

RUN npm install
RUN npm run build

CMD ["node", "server.js"]
