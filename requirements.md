# Analytics & Reporting Requirements

## Objective
Develop SQL-based analytics to provide comprehensive insights into customer segmentation, product performance, and sales performance trends. The solution should enable stakeholders to monitor key KPIs, understand customer behaviour, and identify high-value products and customers across time.

---

## Customer Behaviour
- Provide total customer counts and segmentation by country, gender, and marital status.
- Identify high-value customers based on total revenue contribution and order activity.
- Expose key customer-level KPIs, including total customers and revenue per customer, for use in analytical reporting.

---

## Product Performance
- Identify top-performing products by total revenue, including supporting metrics such as units sold.
- Provide revenue breakdowns by product category, subcategory, and product line to highlight portfolio performance.
- Surface product-related KPIs such as total units sold and average selling price for trend and comparison analysis.

---

## Sales Trends
- Produce revenue trends over time at a monthly granularity, enabling analysis of sales performance across periods.
- Provide core sales KPIs, including total revenue, total customers, total orders, and average order value.
- Highlight product revenue contribution within the overall sales overview to support decision-making on product strategy.

---

## Deliverables
- SQL scripts for each analytical report, implementing the required transformations and aggregations (stored in scripts/gold/).
- A Power BI dashboard consisting of three report pages—Sales Overview, Customer Insights, and Product Insights—visualising the above KPIs, segmentations, rankings, and revenue trends.
