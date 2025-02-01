import formidable from 'formidable';
import { Transform } from 'node:stream';
import { randomUUID } from 'node:crypto';
import { uploadMediaToS3 } from '../clients/s3.js';

/**
 * Uploads a media file to AWS S3 in a streaming fashion.
 * @param {Request} req Express.js (Node) HTTP request object.
 * @return {Promise<string>} The file ID.
 */
export const uploadMedia = async (req) => {
  return new Promise((resolve, reject) => {
    try {
      const uuid = randomUUID();
      const oneHundredMegabytes = 100 * 1024 * 1024;
      const form = formidable({
        maxFiles: 1,
        maxFileSize: oneHundredMegabytes,
        keepExtensions: true,
      });

      form.parse(req, (error, fields, files) => {
        if (error) {
          throw error;
        }
      });

      form.on('error', (error) => {
        throw error;
      });

      form.on('fileBegin', (name, file) => {
        /*
         * Override the default file.open and file.end functions.
         * The file is uploaded S3 once it's open with a stream.
         */
        file.open = function () {
          this._writeStream = new Transform({
            transform(chunk, encoding, callback) {
              this.push(chunk);
              callback();
            },
          });

          this._writeStream.on('error', (error) => {
            form.emit('error', error);
          });

          const key = `${uuid}-${file.originalFilename}`;

          uploadMediaToS3({
            key,
            writeStream: this._writeStream,
          })
            .then((data) => {
              form.emit('data', { name: 'done' });
            })
            .catch((error) => {
              form.emit('error', error);
            });
        };

        file.end = function (callback) {
          this._writeStream.on('finish', () => {
            this.emit('end');
            callback();
          });
          this._writeStream.end();
        };
      });

      form.on('data', (data) => {
        if (data.name === 'done') {
          resolve(uuid);
        }
      });
    } catch (error) {
      reject(error);
    }
  });
};
