# Media Table

The `media` table contains all metadata for media files uploaded to Hummingbird.

## Entities

| Entity | PK                 | SK       |
| ------ | ------------------ | -------- |
| media  | MEDIA#\<media_id\> | METADATA |

## Media Example

#### Create new media

```shell
INPUT=$(mktemp)
cat << EOF > $INPUT
  TableName: $TABLE_NAME
  Item:
    PK: { S: MEDIA#m1 }
    SK: { S: METADATA }
    size: { N: 12345 }
    name: { S: image.png }
    mimetype: { S: image/png }
    bucket: { S: media-bucket }
EOF
aws dynamodb put-item --cli-input-yaml file://$INPUT
rm -f $INPUT
```
