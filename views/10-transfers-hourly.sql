-- Transfers and raw value moved per hour. value_raw has 6 decimals.
CREATE VIEW transfers_hourly AS
  SELECT block_timestamp - (block_timestamp % 3600) AS hour,
         count(*) AS transfers,
         sum(value_dec) AS value_raw
  FROM usdc__transfer
  GROUP BY block_timestamp - (block_timestamp % 3600);
