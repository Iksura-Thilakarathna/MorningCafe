# Business Logic & Financial Accounting Guide

**Application:** Morning Cafe Business Manager  
**Location:** Piliyandala, Sri Lanka  
**Default Currency:** Sri Lankan Rupees (LKR)  
**Default Timezone:** Asia/Colombo (`UTC+05:30`)  

---

## 1. Executive Accounting Architecture

In food businesses, a common accounting error is deducting total bulk purchases directly against weekly sales. Doing so drastically distorts profitability: weeks where bulk supplies are bought show massive artificial losses, while subsequent weeks show artificially inflated profits.

**Morning Cafe Business Manager implements professional managerial accrual accounting tailored for small food enterprises:**

1. **Purchases are capitalized into Inventory Assets:** Buying 10,000 LKR of sausages does not reduce Net Profit; it converts liquid cash into raw material inventory.
2. **COGS reflects actual consumption:** Only the ingredients consumed to produce products sold during the period are charged to Cost of Goods Sold (COGS).
3. **Wastage is an operating expense:** Spoiled, dropped, or expired items are deducted from inventory valuation and recognized as an explicit wastage expense.
4. **Cash Flow is tracked independently:** The cash flow statement tracks actual cash collections versus payments regardless of inventory consumption.

---

## 2. Core Financial Formulas

### 2.1 Sales & Income
$$\text{Sales Revenue} = \sum_{i} (\text{Quantity Sold}_i \times \text{Historical Selling Price}_i)$$

$$\text{Total Business Income} = \text{Sales Revenue} + \text{Additional Income}$$

### 2.2 Cost of Goods Sold (COGS)
$$\text{COGS} = \sum_{j} (\text{Consumed Ingredient Quantity}_j \times \text{FIFO Batch Unit Cost}_j)$$

$$\text{Gross Profit} = \text{Sales Revenue} - \text{COGS}$$

$$\text{Gross Margin \%} = \begin{cases} \left(\frac{\text{Gross Profit}}{\text{Sales Revenue}}\right) \times 100 & \text{if Sales Revenue} > 0 \\ 0.0 & \text{otherwise} \end{cases}$$

### 2.3 Net Profit (The Central Formula)
$$\text{Net Profit} = (\text{Sales Revenue} + \text{Additional Income}) - (\text{COGS} + \text{Wastage Cost} + \text{Operating Expenses})$$

$$\text{Net Profit Margin \%} = \begin{cases} \left(\frac{\text{Net Profit}}{\text{Total Business Income}}\right) \times 100 & \text{if Total Business Income} > 0 \\ 0.0 & \text{otherwise} \end{cases}$$

### 2.4 Cash Flow Statement
$$\text{Cash Inflows} = \text{Sales Collections} + \text{Received Additional Income}$$
$$\text{Cash Outflows} = \text{Paid Ingredient Purchases} + \text{Paid Operating Expenses}$$
$$\text{Net Cash Flow} = \text{Cash Inflows} - \text{Cash Outflows}$$

---

## 3. FIFO (First-In, First-Out) Inventory Engine

Raw food ingredients have limited shelf lives and purchase prices change over time due to inflation. Morning Cafe enforces strict FIFO costing:

### Numerical Walkthrough (Verified in Automated Test 3)

Suppose Morning Cafe purchases sausages across two dates:
- **Batch 1 (March 1):** 50 sausages @ LKR 20.00 each (Valuation: LKR 1,000.00)
- **Batch 2 (March 2):** 30 sausages @ LKR 22.00 each (Valuation: LKR 660.00)
- **Total Initial Stock:** 80 sausages, Total Valuation: LKR 1,660.00

**Event: 60 sausages are consumed in daily production on March 3.**
1. The engine scans for active, non-expired batches ordered by `purchase_date ASC, id ASC`.
2. Batch 1 is depleted first:
   - Takes all 50 units @ LKR 20.00 = LKR 1,000.00
   - Remaining in Batch 1: 0 units (Status updated to `depleted`)
   - Remaining quantity needed: 10 units
3. Batch 2 fulfills the remaining requirement:
   - Takes 10 units @ LKR 22.00 = LKR 220.00
   - Remaining in Batch 2: 20 units @ LKR 22.00 (Status remains `active`)
4. **Calculated COGS:**
   $$\text{Total Cost} = \text{LKR } 1,000.00 + \text{LKR } 220.00 = \text{LKR } 1,220.00$$
5. **Remaining Asset Balance:**
   $$\text{Remaining Quantity} = 20 \text{ units}$$
   $$\text{Remaining Valuation} = 20 \times \text{LKR } 22.00 = \text{LKR } 440.00$$

$$\text{Check: } 1,220.00 + 440.00 = 1,660.00 \quad (\text{Exact penny reconciliation})$$

---

## 4. Shelf-Life Durations & Expiry Exclusion

Small food businesses handle highly perishable items (e.g. prepared burger patties, cut vegetables, fresh buns). 

1. **Usable Duration Setting:** When logging a purchase or opening stock, the owner can specify a usable duration (1–7 days).
2. **Usable End Date Calculation:**
   $$\text{Usable End Date} = \text{Purchase Date} + (\text{Duration Days} - 1)$$
3. **Automated Status Refresh:** Prior to allocating stock for daily sales or showing usable inventory on the dashboard, batches past their `use_by_date` or `usable_end_date` are flagged as `'expired'`.
4. **Production Exclusion:** Expired batches are strictly excluded from recipe production allocation so that expired goods are never calculated as normal product sales. Expired goods must be recorded under **Stock Wastage** with reason `'expired'`.

---

## 5. Bill of Materials (BOM) & Recipe Versioning

### Initial Products & Recipes
| Product Name | Current Retail Price | Recipe Ingredients & Quantities |
| :--- | :--- | :--- |
| **Single Sausage Bun** | LKR 120.00 | 1 Sausage Bun, 1 Sausage, 10 g Tomato Sauce |
| **Double Sausage Bun** | LKR 150.00 | 1 Sausage Bun, 2 Sausages, 10 g Tomato Sauce |
| **Omelette Burger** | LKR 150.00 | 1 Burger Bun, 1 Egg, 15 ml Cooking Oil, 10 g Tomato Sauce, 10 g Mayonnaise, 5 g Salad Leaves |

### Recipe Explosion & Effective Dates
- When a recipe is updated, a new **Recipe Version** is created with an `effective_from` date.
- Sales recorded in the past query the version active on the historical `sale_date`. Past financial statements and ingredient usage records remain 100% stable and intact.
- When recording daily sales, the application calculates theoretical recipe requirements and allows the owner to enter the actual quantity used if there was kitchen variance.

---

## 6. Inventory Balance Reconciliation Identity

To guarantee accounting integrity across reporting periods, the closing valuation must strictly equal:

$$\text{Closing Valuation} = \text{Opening Valuation} + \text{Purchases} - \text{COGS} - \text{Wastage} \pm \text{Physical Adjustments}$$

- **Physical Count Shortage:** Deducts the missing units from the oldest active batches via FIFO and logs an adjustment movement.
- **Physical Count Surplus:** Creates an adjustment batch at the latest known unit cost to bring system stock in line with reality.
- **Verified via Automated Test 13:** All values balance down to LKR 0.00 discrepancy.
