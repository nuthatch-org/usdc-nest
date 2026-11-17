-- Circle's minting and burning, one row per Mint or Burn event. amount_raw has 6 decimals and is
-- negative for a burn, so sum(amount_raw) over a range is the change in totalSupply across it.
CREATE VIEW issuance AS
  SELECT block_number, block_timestamp, tx_hash, log_index, 'mint' AS kind, minter AS actor,
         amount_dec AS amount_raw
  FROM usdc__mint
  UNION ALL
  SELECT block_number, block_timestamp, tx_hash, log_index, 'burn' AS kind, burner AS actor,
         -amount_dec AS amount_raw
  FROM usdc__burn;
