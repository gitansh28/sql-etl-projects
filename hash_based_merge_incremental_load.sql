-- ============================================
-- Hash-Based Incremental Load Pattern
-- Author: Gitansh Kumar
-- Description: Uses hash values to detect changed
-- records and performs MERGE (upsert) from source
-- to destination table. Tracks insert/update counts
-- for monitoring and logging.
-- ============================================

-- Step 1: Capture row count before merge for comparison
DECLARE @BeforeCount INT = 0;
SELECT @BeforeCount = COUNT(1)
FROM dbo.Products WITH (NOLOCK);

-- Step 2: Temp table to capture MERGE output actions
DECLARE @tmp_Products TABLE (
    ActionType VARCHAR(50),
    ProductId INT
);

-- Step 3: MERGE using hash value comparison
-- Insert new records, update only if hash has changed
MERGE INTO dbo.Products TGT
USING dbo.Z_Products SRC
ON SRC.ProductId = TGT.ProductId

WHEN NOT MATCHED THEN
    INSERT (
        ProductId,
        ProductName,
        CategoryName,
        SKU,
        UnitPrice,
        StockQuantity,
        SupplierId,
        WarehouseLocation,
        CreatedBy,
        CreatedOn,
        UpdatedBy,
        UpdatedOn,
        IsActive,
        IsDiscontinued,
        DM_HashValue,
        DM_CreateDateTime,
        DM_LastModifiedDateTime,
        DM_CurrentFlag,
        DM_DeletedFlag
    )
    VALUES (
        SRC.ProductId,
        SRC.ProductName,
        SRC.CategoryName,
        SRC.SKU,
        SRC.UnitPrice,
        SRC.StockQuantity,
        SRC.SupplierId,
        SRC.WarehouseLocation,
        SRC.CreatedBy,
        SRC.CreatedOn,
        SRC.UpdatedBy,
        SRC.UpdatedOn,
        SRC.IsActive,
        SRC.IsDiscontinued,
        SRC.DM_HashValue,
        SRC.DM_CreateDateTime,
        GETDATE(),
        SRC.DM_CurrentFlag,
        SRC.DM_DeletedFlag
    )

-- Only update if hash value has changed (data was modified at source)
WHEN MATCHED AND SRC.DM_HashValue <> TGT.DM_HashValue THEN
    UPDATE SET
        TGT.ProductName = SRC.ProductName,
        TGT.CategoryName = SRC.CategoryName,
        TGT.SKU = SRC.SKU,
        TGT.UnitPrice = SRC.UnitPrice,
        TGT.StockQuantity = SRC.StockQuantity,
        TGT.SupplierId = SRC.SupplierId,
        TGT.WarehouseLocation = SRC.WarehouseLocation,
        TGT.CreatedBy = SRC.CreatedBy,
        TGT.CreatedOn = SRC.CreatedOn,
        TGT.UpdatedBy = SRC.UpdatedBy,
        TGT.UpdatedOn = SRC.UpdatedOn,
        TGT.IsActive = SRC.IsActive,
        TGT.IsDiscontinued = SRC.IsDiscontinued,
        TGT.DM_HashValue = SRC.DM_HashValue,
        TGT.DM_CreateDateTime = SRC.DM_CreateDateTime,
        TGT.DM_LastModifiedDateTime = GETDATE(),
        TGT.DM_CurrentFlag = SRC.DM_CurrentFlag,
        TGT.DM_DeletedFlag = SRC.DM_DeletedFlag

-- Step 4: Capture what was inserted vs updated
OUTPUT
    $action AS ActionType,
    SRC.ProductId
INTO @tmp_Products;

-- Step 5: Count and report results
DECLARE @InsertedRowCount INT = 0;
DECLARE @UpdatedRowCount INT = 0;

SELECT @UpdatedRowCount = COUNT(1)
FROM @tmp_Products WHERE ActionType = 'UPDATE';

SELECT @InsertedRowCount = COUNT(1)
FROM @tmp_Products WHERE ActionType = 'INSERT';

-- Final summary output for monitoring
SELECT
    ISNULL(@InsertedRowCount, 0) AS InsertedRowCount,
    ISNULL(@UpdatedRowCount, 0) AS UpdatedRowCount,
    @BeforeCount AS BeforeCount,
    COUNT(1) AS AfterCount,
    MAX(ISNULL(UpdatedOn, CreatedOn)) AS LastUpdate
FROM dbo.Products WITH (NOLOCK);
