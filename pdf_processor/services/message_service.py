import os
import json
import queue
import threading
import boto3
from botocore.exceptions import ClientError

class MessageQueue:
    """
    A message queue implementation that uses in-memory queues for local development
    and Amazon SQS for Lambda environment
    """
    def __init__(self, queue_name=None, max_size=100):
        # Check if we're running in AWS Lambda
        self.is_lambda = 'AWS_LAMBDA_FUNCTION_NAME' in os.environ
        self.queue_name = queue_name or "default-queue"
        
        if self.is_lambda:
            # Initialize SQS client
            self.sqs = boto3.client('sqs')
            
            # Get queue URL - create if it doesn't exist
            try:
                response = self.sqs.get_queue_url(QueueName=self.queue_name)
                self.queue_url = response['QueueUrl']
            except ClientError as e:
                if e.response['Error']['Code'] == 'AWS.SimpleQueueService.NonExistentQueue':
                    # Create the queue
                    response = self.sqs.create_queue(
                        QueueName=self.queue_name,
                        Attributes={
                            'VisibilityTimeout': '300',  # 5 minutes
                            'MessageRetentionPeriod': '86400'  # 1 day
                        }
                    )
                    self.queue_url = response['QueueUrl']
                else:
                    raise e
        else:
            # Local in-memory queue
            self.queue = queue.Queue(maxsize=max_size)
            self.lock = threading.Lock()

    def add_message(self, message):
        """
        Add a message to the queue
        
        Args:
            message (dict): The message to add
            
        Returns:
            bool: True if successful, False otherwise
        """
        if self.is_lambda:
            try:
                # Convert message to JSON string
                message_body = json.dumps(message)
                
                # Send message to SQS
                self.sqs.send_message(
                    QueueUrl=self.queue_url,
                    MessageBody=message_body
                )
                return True
            except Exception as e:
                print(f"Error adding message to SQS: {e}")
                return False
        else:
            # Local in-memory queue
            try:
                self.queue.put(message, block=False)
                return True
            except queue.Full:
                print("Queue is full")
                return False

    def get_message(self):
        """
        Get a message from the queue
        
        Returns:
            dict: The message, or None if queue is empty
        """
        if self.is_lambda:
            try:
                # Receive message from SQS
                response = self.sqs.receive_message(
                    QueueUrl=self.queue_url,
                    MaxNumberOfMessages=1,
                    VisibilityTimeout=300,  # 5 minutes
                    WaitTimeSeconds=0  # Don't wait for a message
                )
                
                # Check if we got any messages
                if 'Messages' not in response or not response['Messages']:
                    return None
                
                # Get the message
                sqs_message = response['Messages'][0]
                receipt_handle = sqs_message['ReceiptHandle']
                
                # Parse the message body
                message = json.loads(sqs_message['Body'])
                
                # Delete the message from the queue
                self.sqs.delete_message(
                    QueueUrl=self.queue_url,
                    ReceiptHandle=receipt_handle
                )
                
                return message
            except Exception as e:
                print(f"Error getting message from SQS: {e}")
                return None
        else:
            # Local in-memory queue
            try:
                return self.queue.get(block=False)
            except queue.Empty:
                return None

    def is_empty(self):
        """
        Check if the queue is empty
        
        Returns:
            bool: True if queue is empty, False otherwise
        """
        if self.is_lambda:
            try:
                # Check if there are any messages in the queue
                response = self.sqs.get_queue_attributes(
                    QueueUrl=self.queue_url,
                    AttributeNames=['ApproximateNumberOfMessages']
                )
                
                # Get the number of messages
                count = int(response['Attributes']['ApproximateNumberOfMessages'])
                
                return count == 0
            except Exception as e:
                print(f"Error checking if SQS queue is empty: {e}")
                return True
        else:
            # Local in-memory queue
            return self.queue.empty()

    def get_size(self):
        """
        Get the current size of the queue
        
        Returns:
            int: Number of messages in the queue
        """
        if self.is_lambda:
            try:
                # Check how many messages are in the queue
                response = self.sqs.get_queue_attributes(
                    QueueUrl=self.queue_url,
                    AttributeNames=['ApproximateNumberOfMessages']
                )
                
                # Get the number of messages
                return int(response['Attributes']['ApproximateNumberOfMessages'])
            except Exception as e:
                print(f"Error getting SQS queue size: {e}")
                return 0
        else:
            # Local in-memory queue
            return self.queue.qsize()

    def clear(self):
        """
        Clear all messages from the queue
        """
        if self.is_lambda:
            try:
                # Purge the queue
                self.sqs.purge_queue(QueueUrl=self.queue_url)
            except Exception as e:
                print(f"Error clearing SQS queue: {e}")
        else:
            # Local in-memory queue
            with self.lock:
                while not self.queue.empty():
                    try:
                        self.queue.get(block=False)
                    except queue.Empty:
                        break