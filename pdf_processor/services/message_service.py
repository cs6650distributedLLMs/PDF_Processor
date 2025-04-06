import threading
import queue
import json
import os


class MessageQueue:
    """
    A simple in-memory message queue implementation

    This is a simplified version of what you would use in AWS SQS
    In a production environment, you would use a proper message queue system
    """

    def __init__(self, max_size=100):
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
        return self.queue.empty()

    def get_size(self):
        """
        Get the current size of the queue

        Returns:
            int: Number of messages in the queue
        """
        return self.queue.qsize()

    def clear(self):
        """
        Clear all messages from the queue
        """
        with self.lock:
            while not self.queue.empty():
                try:
                    self.queue.get(block=False)
                except queue.Empty:
                    break


class PersistentMessageQueue(MessageQueue):
    """
    A message queue that persists messages to disk

    This is a more robust version that can survive application restarts
    """

    def __init__(self, queue_name, storage_dir="./queue_data", max_size=100):
        super().__init__(max_size)
        self.queue_name = queue_name
        self.storage_dir = storage_dir
        self.storage_path = os.path.join(storage_dir, f"{queue_name}.json")

        # Create storage directory if it doesn't exist
        os.makedirs(storage_dir, exist_ok=True)

        # Load any persisted messages
        self._load_from_disk()

    def add_message(self, message):
        """
        Add a message to the queue and persist to disk

        Args:
            message (dict): The message to add

        Returns:
            bool: True if successful, False otherwise
        """
        result = super().add_message(message)
        if result:
            self._save_to_disk()
        return result

    def get_message(self):
        """
        Get a message from the queue and update persistence

        Returns:
            dict: The message, or None if queue is empty
        """
        message = super().get_message()
        if message is not None:
            self._save_to_disk()
        return message

    def _save_to_disk(self):
        """
        Save the current queue state to disk
        """
        with self.lock:
            # Convert queue to list
            queue_list = list(self.queue.queue)

            try:
                with open(self.storage_path, "w") as f:
                    json.dump(queue_list, f)
            except Exception as e:
                print(f"Error saving queue to disk: {e}")

    def _load_from_disk(self):
        """
        Load queue state from disk
        """
        if not os.path.exists(self.storage_path):
            return

        try:
            with open(self.storage_path, "r") as f:
                queue_list = json.load(f)

                # Clear current queue
                self.clear()

                # Add loaded messages to queue
                for message in queue_list:
                    try:
                        self.queue.put(message, block=False)
                    except queue.Full:
                        print("Queue is full, skipping remaining messages")
                        break
        except Exception as e:
            print(f"Error loading queue from disk: {e}")
