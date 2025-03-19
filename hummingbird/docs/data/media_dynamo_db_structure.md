# Media Table

The `media` table contains all metadata for media files uploaded to Hummingbird.

## Entities

| PK                 | SK       |
|--------------------|----------|
| MEDIA#\<media_id\> | METADATA |

Notice that the DynamoDB table schema only requires PK (primary key) and SK (sort key) for a record to be stored.
All other values, such as `size` and `name`, are schemaless: they are not defined in the schema and records may or may
not include those fields.

## Dynamo Query Examples

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
    status: { S: PENDING }
    width: { N: 1024 }
EOF
aws dynamodb put-item --cli-input-yaml file://$INPUT
rm -f $INPUT
```
