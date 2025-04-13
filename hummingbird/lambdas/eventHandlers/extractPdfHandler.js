const { Span } = require('@opentelemetry/api');
const opentelemetry = require('@opentelemetry/api');
const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const pdfParse = require('pdf-parse');
const { getLogger } = require('../logger');
const { setMediaStatusConditionally } = require('../clients/dynamodb.js');
const { getMediaFile, uploadMediaToStorage } = require('../clients/s3.js');
const { MEDIA_STATUS, BUCKETS } = require('../core/constants.js');
const { setMediaStatus } = require('../clients/dynamodb');
const { successesCounter, failuresCounter } = require('../observability.js');
const { getBaseName } = require('../core/utils.js');

const logger = getLogger();

const meter = opentelemetry.metrics.getMeter(
  'hummingbird-async-media-processing-lambda'
);

const metricScope = 'extractPdfHandler';

/**
 * Extract text from a PDF file
 * @param {object} param0 The function parameters
 * @param {string} param0.mediaId The media ID for extraction
 * @param {Span} param0.span OpenTelemetry trace Span object
 * @returns {Promise<void>}
 */
const extractPdfHandler = async ({ mediaId, span }) => {
  if (!mediaId) {
    logger.info('Skipping extract PDF message with missing mediaId.');
    return;
  }

  try {
    // Set media status to PROCESSING
    const { name: mediaName } = await setMediaStatusConditionally({
      mediaId,
      newStatus: MEDIA_STATUS.PROCESSING,
      expectedCurrentStatus: MEDIA_STATUS.PENDING,
    });

    // Get the PDF file from S3
    const pdfData = await getMediaFile({
      mediaId,
      mediaName,
      keyPrefix: BUCKETS.UPLOADS,
    });

    // Extract the text content
    const processingStart = performance.now();
    const extractedText = await extractTextFromPdf(pdfData);
    const processingEnd = performance.now();

    span.addEvent('pdf.extraction.done', {
      'media.processing.duration': Math.round(processingEnd - processingStart),
    });

    const basename = getBaseName(mediaName);

    await uploadMediaToStorage({
      mediaId,
      mediaName: `${basename}.extracted.txt`,
      body: Buffer.from(extractedText),
      keyPrefix: BUCKETS.EXTRACTS,
    });

    await setMediaStatus({ mediaId, newStatus: MEDIA_STATUS.EXTRACTED });

    logger.info('PDF extraction complete', {
      mediaId,
      charCount: extractedText.length,
    });

    span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
    successesCounter.add(1, { scope: metricScope });
  } catch (error) {
    span.setStatus({ code: opentelemetry.SpanStatusCode.ERROR });

    if (error instanceof ConditionalCheckFailedException) {
      logger.error(`Media ${mediaId} not found or status is not as expected.`);
      span.end();
      failuresCounter.add(1, {
        scope: metricScope,
        reason: 'CONDITIONAL_CHECK_FAILURE',
      });
      throw error;
    }

    await setMediaStatus({ mediaId, newStatus: MEDIA_STATUS.ERROR });
    logger.error(`Failed to extract text from PDF ${mediaId}`, error);
    span.end();
    failuresCounter.add(1, {
      scope: metricScope,
    });
    throw error;
  } finally {
    logger.info('Flushing OpenTelemetry signals');
    await global.customInstrumentation.metricReader.forceFlush();
    await global.customInstrumentation.traceExporter.forceFlush();
  }
};

/**
 * Extracts text from a PDF buffer using pdf-parse
 * @param {Buffer} pdfData The PDF buffer
 * @returns {Promise<string>} The extracted text
 */
const extractTextFromPdf = async (pdfData) => {
  try {
    return await pdfParse(pdfData);
  } catch (error) {
    logger.error('Error extracting text from PDF', error);
    throw error;
  }
};

module.exports = extractPdfHandler;
