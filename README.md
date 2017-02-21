### Wire format (ABNF)

```
message = command [ ":" args ]
dancerMessage = dancerId ":" message
args = position
position = jsonNumber "," jsonNumber
```
