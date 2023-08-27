# seQura Disbursements System

This application is designed to automate the calculation of merchants’ disbursements payouts and seQura commissions. It includes processes to handle large datasets efficiently and ensures accurate financial operations.

### Disbursement Summary Table

| Year | Number of disbursements | Amount disbursed to merchants | Amount of order fees | Number of monthly fees charged (From minimum monthly fee) | Amount of monthly fee charged (From minimum monthly fee) |
|------|-------------------------|-------------------------------|----------------------|------------------------------------------------------|----------------------------------------------------------|
| 2022 | 1450                    | 14.518.175,80 €               | 124.490,81 €         | 18                                                   | 233,43 €                                                 |
| 2023 | 1186                    | 15.308.971,43 €               | 131.264,29 €         | 185                                                  | 3.868,55 €                                               |


## Setup:

### 1. Rails and Database:
- Used a Rails application 
- Integrated the `money-rails` gem for better money handling.
- All the values are stored in cents so we dont have rounding issues

### 2. Models:
- **Merchant**: 
- **Order**:
- **Disbursement**:

### 3. Importing Data from CSV:
- Created Rake tasks to import merchants and orders from CSV files.
- Sanitizes emails during import.
- Optimized import strategies for large datasets.

### 4. Background Processing with Sidekiq:
- Integrated `sidekiq` for asynchronous job processing.
- Daily disbursements processed using Sidekiq workers.
- Scheduled tasks using `sidekiq-scheduler`.

## Usage:

### 1. CSV Import:

**Import Merchants**:
   ```bash
   rake import:merchants
   ```

**Import Orders**:
   ```bash
   rake import:orders
   ```

### 2. Sidekiq:
- Start Sidekiq:
  ```bash
  bundle exec sidekiq
  ```
- `DisbursementWorker` runs daily at 7:00 UTC to process disbursements for eligible merchants.

## Features:

### 1. Disbursements Calculation:
- All orders are disbursed precisely once.
- Unique alphanumerical reference for each disbursement.
- Order-based commission calculation.
- Checks for `minimum_monthly_fee` on the first disbursement of each month.

### 2. Efficiency:
- Data import that doesn't load the entire CSV into memory.
- Cached merchant references during order imports.
- Optimized for large datasets using batch processing.
- when dealing with calculations used the sum from the database to 
better performance tried to instantiate only the needed parts

### 3. Sanitization:
- Email sanitization during CSV import for data integrity.
- During the order import check if the Merchant exits added references in the 
database and index to minimize data corruption

## Future Enhancements:

1. On the services that import data if a batch has bad data on it we discard the whole batch this can be imporved
2. Integrate error handling and notifications for failed jobs in Sidekiq.
3. Improve reporting capabilities for orders, amounts, and fees included in disbursements.
4. Add more coverage to the more complex part ( the worker )

---

## DisbursementWorker

The `DisbursementWorker` class is a utility designed to process disbursements for merchants. It calculates and processes disbursements for all registered merchants, taking into consideration the specific frequency (daily or weekly) at which each merchant prefers to receive their payments.

### Technical Choices & Assumptions:

1. **Sidekiq Integration**: the decision to use Sidekiq for this worker because it provides a robust background job processing capability. This ensures that our disbursement process doesn't block other operations, especially if the number of merchants or orders is large.

2. **Batch Processing with `Merchant.find_each`**: Instead of loading all merchants into memory, used the `find_each` method to retrieve them in batches. This makes the memory footprint predictable regardless of the total number of merchants.

3. **Date Iteration based on Disbursement Frequency**: The worker considers the disbursement frequency of each merchant (daily or weekly) to process the disbursements accordingly. This is achieved through the `date_iterator_for` method.

4. **Deferred Fee Calculation**: Fees are calculated based on the total amount disbursed. Different slabs of fees exist based on the disbursement amount, ensuring a fair fee structure.

5. **Monthly Minimum Fee**: If the fee from transactions is less than the minimum monthly fee, a correction is applied. This ensures the merchant always pays the minimum monthly fee.

6. **Atomicity in Disbursement Creation**: The disbursement record creation and linking to orders is done atomically. This ensures that we don't end up with orders linked to a failed disbursement record.

### Tradeoffs:

- **Performance vs Freshness**: Instead of processing disbursements in real-time, went with a batch-based approach which might have a delay but ensures optimal performance.

- **Complexity**: To handle various scenarios like monthly fees, different fee slabs, and varying disbursement frequencies, the worker has a fair bit of complexity. However, it's organized into smaller methods for clarity.

### Left Aside due to Time Constraints:

1. **Error Handling**: While the basic structure is in place, more comprehensive error handling and reporting mechanisms need to be integrated. This would ensure that any issues during the disbursement process are quickly identified and addressed.

2. **Performance Optimizations**: Although the current setup works efficiently for a moderate number of merchants and orders, specific optimizations can be done, especially in SQL queries and iterations, when the data size grows significantly.

3. **Testing**: Comprehensive unit tests for this worker would be essential. While some basic tests might exist, ensuring full coverage, especially around edge cases, would be the next step.

### How to Resolve/Improve:

1. **Parallel Processing**: If the number of merchants grows, we could split the job into multiple smaller jobs that can run in parallel, ensuring faster processing.

2. **Distributed Locking**: To ensure that two workers don't process the same merchant's disbursements simultaneously, we could introduce distributed locking mechanisms.

3. **Introduce a Retry Mechanism**: If for any reason a disbursement for a merchant fails, having a retry mechanism with exponential backoff could be beneficial.

4. **Monitoring and Alerting**: Integrate the worker with monitoring tools to get insights into its performance, failures, and ensure timely alerts in case of issues.

### Usage:

To trigger the disbursement process:

```ruby
DisbursementWorker.perform_async
```

Ensure you have Sidekiq running and integrated with your application.

### Dependencies:

- `Sidekiq`: For background job processing.


## Description of `MerchantImporterService`

The `MerchantImporterService` is a service class responsible for importing merchant data from a provided CSV file into the system. The class serves as a pipeline for extracting, transforming, and loading (ETL) the merchant data.

**Key Components and Processes:**

1. **Initialization**: Upon instantiation, it requires a file path to the CSV to be imported and sets up a logger.

2. **Parsing**: It uses Ruby's CSV library to parse the file. Each row from the CSV file is read and transformed into a hash of attributes suitable for creating a Merchant record.

3. **Transformation**: During this phase:
  - Email addresses are sanitized by removing any character that doesn't match a predefined regular expression.
  - The currency is set to a default value ('EUR').
  - The minimum monthly fee is converted from float to an integer (multiplied by 100, presumably to handle cents).

4. **Loading**: Merchants are inserted in batches (defined by `BATCH_SIZE`) to optimize the database writes.

5. **Logging**: Any errors during the import process, or during the bulk insert, are logged. Successful imports are also logged.

6. **Transactions**: The bulk insert process is wrapped in a database transaction to ensure data integrity. If one insert fails, all inserts in that batch will be rolled back.

## Possible Improvements:

1. **Validation**:
  - Currently, the service assumes that the provided data is mostly correct. It might be beneficial to add validations for essential fields (e.g., checking if the `email` is in a valid format or if `reference` is unique).
  - Use ActiveRecord validations for merchant attributes and handle validation errors.

2. **Error Handling**:
  - Instead of just logging errors, the service could also return these errors so that they can be presented to the user or be processed further.
  - Specific error messages for different types of errors, like malformed CSV, missing required columns, or invalid data.

3. **Configurability**:
  - Allow for configurable batch sizes or default currencies instead of hardcoding them. This can be useful if you need to adjust based on performance metrics or different use cases.

4. **Extensibility**:
  - The service is specific to importing merchants. An abstracted version could be created to handle different types of CSV imports, making the system more extensible.
  - Allow for custom transformations or additional steps in the ETL process if required in the future.

5. **Feedback**:
  - Provide feedback on the number of successful imports vs. failed ones.
  - Allow for a dry-run mode where the import is simulated but no data is actually saved. This lets users check the potential output before committing.

6. **Integration with External Systems**:
  - If the data comes from or goes to external systems, consider adding integrations or notifications to inform these systems about the import status.
