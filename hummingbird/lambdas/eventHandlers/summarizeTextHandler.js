const { Span } = require('@opentelemetry/api');
const opentelemetry = require('@opentelemetry/api');
const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const axios = require('axios');
const { getLogger } = require('../logger');
const {
  setMediaStatus,
  setMediaStatusConditionally,
} = require('../clients/dynamodb.js');
const { getMediaFile, uploadMediaToStorage } = require('../clients/s3.js');
const { MEDIA_STATUS, BUCKETS } = require('../core/constants.js');
const { successesCounter, failuresCounter } = require('../observability.js');
const { getBaseName } = require('../core/utils.js');

const logger = getLogger();

const meter = opentelemetry.metrics.getMeter(
  'hummingbird-async-media-processing-lambda'
);

const metricScope = 'summarizeTextHandler';

/**
 * Summarize extracted text using an LLM
 * @param {object} param0 The function parameters
 * @param {string} param0.mediaId The media ID for summarization
 * @param {string} param0.mediaName The original file name
 * @param {string} param0.style The summarization style
 * @param {Span} param0.span OpenTelemetry trace Span object
 * @returns {Promise<void>}
 */
const summarizeTextHandler = async ({ mediaId, style, span }) => {
  if (!mediaId) {
    logger.info('Skipping summarize text message with missing mediaId.');
    return;
  }

  try {
    // Summarization is only allowed if the status is EXTRACTED.
    // This ensures that extraction was successful and completed.
    // If the status is anything else, extraction may have failed or is still in progress.
    const { name: mediaName } = await setMediaStatusConditionally({
      mediaId,
      newStatus: MEDIA_STATUS.PROCESSING,
      expectedCurrentStatus: MEDIA_STATUS.EXTRACTED,
    });

    logger.info(
      `Summarizing text for PDF with id ${mediaId} using style: ${style}.`
    );

    const basename = getBaseName(mediaName);
    // Get the extracted text from S3
    const textData = await getMediaFile({
      mediaId,
      mediaName: `${basename}.extracted.txt`,
      keyPrefix: BUCKETS.EXTRACTS,
    });

    const extractedText = new TextDecoder().decode(textData);
    logger.info(
      `Retrieved ${extractedText.length} characters of extracted text for media ${mediaId}`
    );

    // Generate the summary using LLM
    const processingStart = performance.now();
    const summary = await generateSummaryWithLLM(extractedText, style);
    const processingEnd = performance.now();

    span.addEvent('text.summarization.done', {
      'media.processing.duration': Math.round(processingEnd - processingStart),
    });

    logger.info(
      `Generated summary with ${summary.length} characters for media ${mediaId}`
    );

    // Save the summary to S3
    await uploadMediaToStorage({
      mediaId,
      mediaName: `${basename}.summary.txt`,
      body: Buffer.from(summary),
      keyPrefix: BUCKETS.SUMMARIES,
    });

    logger.info(`Uploaded summary for media ${mediaId} to S3`);

    // Update media status to COMPLETE
    await setMediaStatus({ mediaId, newStatus: MEDIA_STATUS.SUMMARIZED });

    logger.info(`Summarization complete for media ${mediaId}`);
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

    logger.error(`Failed to summarize text for ${mediaId}`, error);
    span.end();
    failuresCounter.add(1, { scope: metricScope });
    throw error;
  } finally {
    logger.info('Flushing OpenTelemetry signals');
    await global.customInstrumentation.metricReader.forceFlush();
    await global.customInstrumentation.traceExporter.forceFlush();
  }
};

/**
 * Generates a summary of the given text using an LLM API
 * @param {string} text The text to summarize
 * @param {string} style The summarization style
 * @returns {Promise<string>} The summary text
 */
const generateSummaryWithLLM = async (text, style) => {
  if (!process.env.XAI_API_KEY) {
    logger.error('XAI_API_KEY is not set. Cannot generate summary.');
    throw new Error('XAI_API_KEY is not set');
  }

  try {
    // Prepare the prompt based on the style
    let prompt;

    switch (style) {
      case 'detailed':
        prompt = `Please provide a detailed summary of the following text, including key points, main arguments, and important details: ${text}`;
        break;
      case 'bullet-points':
        prompt = `Please summarize the following text in bullet points, highlighting the most important information: ${text}`;
        break;
      case 'concise':
      default:
        prompt = `Please provide a concise summary of the following text: ${text}`;
    }

    // Truncate text if it's too long (adjust based on model limitations)
    const MAX_TOKENS = 8000;
    const truncatedPrompt =
      prompt.length > MAX_TOKENS
        ? prompt.substring(0, MAX_TOKENS) + '... [text truncated due to length]'
        : prompt;

    // Make API request to LLM
    const response = await axios.post(
      'https://api.x.ai/v1/chat/completions',
      {
        messages: [
          {
            role: 'system',
            content:
              'You are an AI assistant specialized in summarizing documents.',
          },
          {
            role: 'user',
            content: truncatedPrompt,
          },
        ],
        model: 'grok-3-mini-beta',
        stream: false,
        temperature: 0.3,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${process.env.XAI_API_KEY}`,
        },
      }
    );

    return response.data.choices[0].message.content;
  } catch (error) {
    logger.error(
      `Error generating summary with LLM for media ${mediaId}`,
      error
    );
    throw error;
  }
};

module.exports = summarizeTextHandler;
