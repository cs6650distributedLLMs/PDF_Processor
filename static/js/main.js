/**
 * Main JavaScript file for the PDF Processing Application
 */

document.addEventListener("DOMContentLoaded", function () {
  // File input validation
  const fileInput = document.getElementById("file");
  if (fileInput) {
    fileInput.addEventListener("change", function () {
      const file = this.files[0];
      if (file) {
        // Check file type
        if (!file.type.match("application/pdf")) {
          alert("Please select a valid PDF file.");
          this.value = ""; // Clear the input
          return;
        }

        // Check file size (16MB max)
        const maxSize = 16 * 1024 * 1024; // 16MB in bytes
        if (file.size > maxSize) {
          alert("File is too large. Maximum size is 16MB.");
          this.value = ""; // Clear the input
          return;
        }
      }
    });
  }

  // Poll for status updates on the results page
  const statusElement = document.getElementById("status-message");
  if (statusElement && window.location.pathname.includes("/status/")) {
    const jobId = window.location.pathname.split("/").pop();

    // If not already polling and not completed or failed
    const currentStatus = statusElement.textContent.trim().split(":")[1].trim();
    if (!currentStatus.includes("completed") && !currentStatus.includes("failed")) {
      pollStatus(jobId);
    }
  }
});

/**
 * Poll the API for job status updates
 * @param {string} jobId - The ID of the job to check
 */
function pollStatus(jobId) {
  const statusCheckInterval = setInterval(function () {
    fetch(`/api/status/${jobId}`)
      .then((response) => response.json())
      .then((data) => {
        const currentStatus = document.getElementById("status-message").textContent.trim().split(":")[1].trim();
        const newStatus = data.status;

        // Update status if changed
        if (currentStatus !== newStatus) {
          // Refresh the page to show updated UI
          window.location.reload();
        }

        // Stop polling if completed or failed
        if (newStatus === "completed" || newStatus.includes("failed")) {
          clearInterval(statusCheckInterval);
        }
      })
      .catch((error) => {
        console.error("Error checking status:", error);
      });
  }, 3000); // Check every 3 seconds
}
