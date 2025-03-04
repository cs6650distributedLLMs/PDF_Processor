import { Transform } from 'node:stream';
import { randomUUID } from 'node:crypto';
import formidable, { errors as formidableErrors } from 'formidable';
import opentelemetry from '@opentelemetry/api';
import { uploadMediaToStorage } from '../clients/s3.js';
import { MAX_FILE_SIZE, CUSTOM_FORMIDABLE_ERRORS } from '../core/constants.js';

const tracer = opentelemetry.trace.getTracer('hummingbird-media-upload');

/**
 * Uploads a media file to AWS S3 in a streaming fashion.
 * @param {Request} req Express.js (Node) HTTP request object.
 * @return {Promise<string>} The file ID.
 */
export const uploadMedia = async (req) => {
  return new Promise((resolve, reject) => {
    try {
      tracer.startActiveSpan('upload-media-file', (span) => {
        const mediaId = randomUUID();
        span.setAttribute('media-id', mediaId);

        const form = formidable({
          maxFiles: 1,
          minFileSize: 1,
          maxFileSize: MAX_FILE_SIZE,
          keepExtensions: true,
          filter: ({ mimetype }) => {
            const isImage = mimetype && mimetype.startsWith('image');
            if (!isImage) {
              const { code, httpCode } =
                CUSTOM_FORMIDABLE_ERRORS.INVALID_FILE_TYPE;
              const error = new formidableErrors.default(
                'invalidFileType',
                code,
                httpCode
              );
              form.emit('error', error);
              return false;
            }

            return true;
          },
        });

        form.parse(req, (error, fields, files) => {
          if (!Object.keys(files).length) {
            const error = new formidableErrors.default(
              'noFilesFound',
              formidableErrors.malformedMultipart,
              400
            );
            form.emit('error', error);
            return;
          }

          if (error) {
            reject(error);
          }
        });

        form.on('error', (error) => {
          span.setStatus({
            code: opentelemetry.SpanStatusCode.ERROR,
            message: error.message,
          });
          span.end();
          reject(error);
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

            uploadMediaToStorage({
              mediaId,
              mediaName: file.originalFilename,
              body: this._writeStream,
            })
              .then(() => {
                span.setAttribute('file-name', file.originalFilename);
                form.emit('data', { event: 'done', file });
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
          if (data.event === 'done') {
            span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
            span.end();
            resolve({ mediaId, file: data.file.toJSON() });
          }
        });
      });
    } catch (error) {
      reject(error);
    }
  });
};
