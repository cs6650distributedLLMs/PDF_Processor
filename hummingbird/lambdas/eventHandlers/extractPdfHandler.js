const { Span } = require('@opentelemetry/api');
const opentelemetry = require('@opentelemetry/api');
const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const pdfParse = require('pdf-parse');
const { getLogger } = require('../logger');
const { setMediaStatusConditionally } = require('../clients/dynamodb.js');
const { getMediaFile, uploadMediaToStorage } = require('../clients/s3.js');
const { MEDIA_STATUS } = require('../constants.js');
const { setMediaStatus } = require('../clients/dynamodb');
const { successesCounter, failuresCounter } = require('../observability.js');
const { publishSummarizeTextEvent } = require('../clients/sns');

const logger = getLogger();

const meter = opentelemetry.metrics.getMeter(
  'hummingbird-async-media-processing-lambda'
);

const metricScope = 'extractPdfHandler';

/**
 * Extract text from a PDF file
 * @param {object} param0 The function parameters
 * @param {string} param0.mediaId The media ID for extraction
 * @param {string} param0.style The summarization style
 * @param {Span} param0.span OpenTelemetry trace Span object
 * @returns {Promise<void>}
 */
const extractPdfHandler = async ({ mediaId, style, span }) => {
  if (!mediaId) {
    logger.info('Skipping extract PDF message with missing mediaId.');
    return;
  }

  logger.info(`Extracting text from PDF with id ${mediaId}.`);

  try {
    // Set media status to PROCESSING
    const { name: mediaName } = await setMediaStatusConditionally({
      mediaId,
      newStatus: MEDIA_STATUS.PROCESSING,
      expectedCurrentStatus: MEDIA_STATUS.PENDING,
    });

    logger.info('Media status set to PROCESSING');

    // Get the PDF file from S3
    const pdfData = await getMediaFile({ mediaId, mediaName });

    logger.info('Got PDF file');

    // Extract the text content
    const processingStart = performance.now();
    const extractedText = await extractTextFromPdf(pdfData);
    const processingEnd = performance.now();

    span.addEvent('pdf.extraction.done', {
      'media.processing.duration': Math.round(processingEnd - processingStart),
    });

    // logger.info(`Extracted ${extractedText} from PDF`)

    logger.info(`Extracted ${extractedText.length} characters from PDF`);

    // Save the extracted text to S3
    await uploadMediaToStorage({
      mediaId,
      mediaName: `${mediaName}.txt`,
      body: Buffer.from(extractedText),
      keyPrefix: 'extracted',
    });

    logger.info('Uploaded extracted text');

    // Trigger the summarization process
    await publishSummarizeTextEvent({
      mediaId,
      mediaName,
      style,
    });

    logger.info(`PDF text extraction complete for ${mediaId}`);
    span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
    successesCounter.add(1, {
      scope: metricScope,
    });
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

    await setMediaStatus({
      mediaId,
      newStatus: MEDIA_STATUS.ERROR,
    });

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
    // Parse the PDF data using pdf-parse
    const data = await pdfParse(pdfData);

    // logger.info(`Extracted Text from pdf ${data}`);

    // Return the extracted text
    return data;
  } catch (error) {
    logger.error('Error extracting text from PDF', error);

    return `
        During Donald Trump’s first term, advisers who wanted to check his most dramatic impulses reliably turned to two places to act as guardrails: the stock market and cable news. If the markets reacted badly to something Trump did, they found, he would likely change course to match Wall Street’s moves. And television’s hold over Trump was so great that, at times, his aides would look to get booked on a cable-news show, believing that the president would be more receptive to an idea he heard there than one floated during an Oval Office meeting.
    But Trump’s second term looks different. Taking further steps today to escalate his global trade war, the president has ignored the deep plunges on Wall Street that have cost the economy trillions of dollars and accelerated risks of a bear market. He has tuned out the wall-to-wall coverage, at least on some cable networks, about the self-inflicted wounds he has dealt the United States economy. And unlike eight years ago, few members of Trump’s team are looking to rein him in, and those who think differently have almost all opted against publicly voicing disagreement.
    Trump is showing no signs—at least not yet—of being encumbered by political considerations as he makes the biggest bet of his presidency, according to three White House officials and two outside allies granted anonymity to discuss the president’s decision making. Emboldened by his historic comeback, he believes that launching a trade battle is his best chance of fundamentally remaking the American economy, elites and experts be damned.
    “This man was politically dead and survived both four criminal cases and an assassination attempt to be president again. He really believes in this and is going to go big,” one of the outside allies told me. “His pain threshold is high to get this done.”
    What’s not clear, even to some of those closest to him, is what will count as a victory.
    The president has likened his tariffs to “medicine” for a sick patient, but they have caused widespread confusion—particularly over whether Trump is committed to keeping the plan in place for years to boost U.S. manufacturing or whether he is using the new tariffs as a negotiating ploy to force other countries to change their policies.
    Read: Trade will move on without the United States
    “We have many, many countries coming to negotiate deals with us, and they’re going to be fair deals,” Trump told reporters today in the Oval Office, adding that he will not pause the tariffs despite another day of Wall Street turbulence. “No other president’s going to do this, what I’m doing.”
    Markets plunged around the globe today for the third-straight trading day after Trump announced the sweeping “Liberation Day” set of tariffs—imposed on nearly all of the world’s economies—that almost instantly remade the United States’ trading relationship with the rest of the world. He has said that Americans should expect short-term pain (“HANG TOUGH,” he declared on social media) as he attempts to make the U.S. economy less dependent on foreign-made goods.
    Recommended Reading
    A man rolling black paint over a mural of Robert E. Lee
    The Myth of the Kindly General Lee
    Adam Serwer
    The Hidden Costs of P.E.
    Catherine Spangler, Vishakha Darbha, and Jackie Lay
    Procrastinate Better
    Olga Khazan
    The blowback has been extensive and relentless. Other nations have responded with retaliatory levies. Fears of a recession have spiked. CEOs, after panicking privately for days, are beginning to speak out. Most cable channels have been bathed in the red of graphs depicting plunging markets, the stock ticker in the corner falling ever downward. Even Fox News, which has downplayed the crisis, has begun carrying stories about the impact on Trump voters who are worried about shrinking retirement accounts and rising prices. GOP lawmakers, usually loath to cross the White House, are mulling trying to limit the president’s economic authority. Senator Ted Cruz worried that the tariffs will cause a 2026 midterms “bloodbath,” while seven other GOP senators, including Trump allies such as Chuck Grassley, signed on to a bipartisan bill that would require Congress to approve Trump’s steep tariffs on trading partners.
    Trump has stayed committed to the tariffs, and he lashed out today on social media at wavering Republicans, declaring them “Weak and Stupid” and warning, “Don’t be a PANICAN,” while his staff promised a veto of the bipartisan bill.
    Yet even within Trump’s administration, the president’s moves have caused widespread confusion about what he is trying to get out of the tariffs. Peter Navarro, one of the administration’s most influential voices on trade, wrote in the Financial Times, “This is not a negotiation. For the US, it is a national emergency triggered by trade deficits caused by a rigged system.” Just a short time later, Treasury Secretary Scott Bessent wrote on social media that he had been tasked by Trump to begin negotiations with Japan and that he looks “forward to our upcoming productive engagement regarding tariffs, non-tariff trade barriers, currency issues, and government subsidies.”
    That public disconnect has brought private disagreements into the light, two of the White House officials and the other outside ally told me. Navarro and White House Deputy Chief of Staff Stephen Miller—who is perceived by many in Trump’s orbit as the most powerful aide on most issues—have embraced the idea that the tariffs should be permanent to erase trade deficits with other countries and even punish some nations, including China, for what the White House says are decades of unfair trade practices. Steve Bannon, the influential outside Trump adviser, has said on his podcast that bringing nations to the negotiating table is not enough and that the White House needs to insist that companies make commitments to bolster domestic manufacturing.
    Bessent, a former hedge-fund manager who once worked for George Soros, has expressed some hesitancy behind closed doors about the tariffs, according to two of the White House officials. (The Treasury Department did not immediately respond to a request for comment.) While stopping short of disagreeing with Trump, Bessent has tried in public interviews to soften the impact of the duties. Yesterday, he said on Meet the Press that “I see no reason that we have to price in a recession” and hinted that the tariffs could be temporary because a number of nations have already sought negotiations. Meanwhile, Elon Musk, who to this point has been Trump’s most visible adviser, today posted a well-known video of the economist Milton Friedman touting free trade. That followed a weekend during which Musk took aim at Navarro, suggesting that his push for steep trade barriers is too extreme.
    Trump himself hardly cleared up the inconsistent messaging when asked in the Oval Office this afternoon if the tariffs are a negotiating tool or are going to be permanent. “Well, they can both be true,” Trump said. “There can be permanent tariffs, and there can also be negotiations, because there are things that we need beyond tariffs.”
    Earlier in the day, the confused messaging had a material impact on the markets: A social-media post misconstruing a comment by National Economic Council Director Kevin Hassett to suggest that Trump might pause the tariffs for 90 days briefly sent markets upward. The White House clarified that no change in policy was planned, prompting markets to go back down.
    That brief rally also seemed to reveal Wall Street’s wishful thinking that the president will soon back off the tariffs—the same sense of optimism that mistakenly led investors to hope before last week that Trump’s campaign rhetoric about tariffs was just a bluff or a negotiating tactic. In a lengthy social-media post yesterday, the hedge-fund manager Bill Ackman, a staunch Trump supporter, wrote that the president needs to pause the tariffs or risk “a self-induced economic nuclear winter.”
    Annie Lowrey: Here are the places where the recession has already begun
    Many Republicans had hoped that Trump’s economic policy would focus on extending his 2017 tax cuts (which disproportionately helped businesses and the wealthy) while also tackling inflation. But although Trump has long possessed a flexible ideology, one of his few consistent principles, dating to at least the 1980s, is a belief in tariffs, even though many economists believe that tariffs are outdated and ineffective in an era of globalization.
    Trump has done little to enact his campaign promise to bring down prices and has surprised some observers with his willingness to endanger his poll numbers by taking on such a risky tariff scheme. Although Trump is notorious for changing his mind on a whim, he is for now ignoring the complaints from business leaders and the warnings about the tariffs’ effect on his own voters.
    There was another small marker recently of how Trump has changed from eight years ago. During his first administration, he regularly grew angry about any media coverage—particularly photographs—that portrayed him unflatteringly. Over the weekend, the front page of The Wall Street Journal carried a photo taken of Trump on Saturday, as he rode in the back of a vehicle wearing golf attire, waving, and talking on the phone, mouth open. The headline read: “Trump Heads to Golf Club Amid Tariff Turmoil.”
    Yet Trump has not complained about the coverage, one of the White House officials told me. And he golfed again yesterday.
    `;

    // throw error;
  }
};

module.exports = extractPdfHandler;
