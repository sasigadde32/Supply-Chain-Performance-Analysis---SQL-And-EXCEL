--For each Product_type, calculate:Product_type,Number of SKUs,Total Products Sold
--Total Revenue Generated,Average Selling Price,Average Revenue per SKU
SELECT Product_type,
	   COUNT(SKU) AS no_of_SKU,
	   SUM(Number_of_products_sold) AS Total_Products_Sold,
	   ROUND(SUM(Revenue_generated),0) AS Total_Revenue_generated,
	   ROUND(AVG(Price),2) AS Avg_Selling_Price,
	   ROUND(AVG(Revenue_generated),2) Avg_Revenue_SKU
	   FROM supply_chain_data
	   GROUP BY Product_type

--The operations team wants to know which suppliers are producing the best quality products.
--For each supplier calculate:Supplier_name,Number of SKUs supplied,Total Revenue Generated,Average Defect Rate
--Pass Rate (%),Fail Rate (%),Pending Rate (%),Overall Supplier Quality
WITH Supplier_stats AS 
(
SELECT
	  Supplier_name,
	  COUNT(SKU) AS No_Of_SKU,
	  SUM(Revenue_generated) AS Total_Revenue_Generated,
	  AVG(Defect_rates) AS Avg_Defect_Rate,
	  ROUND(100.0*SUM(CASE WHEN Inspection_results = 'Pass' THEN 1 END)/COUNT(*),2) AS Pass_Rate,
	  ROUND(100.0*SUM(CASE WHEN Inspection_results = 'Fail' THEN 1 END)/COUNT(*),2) AS Fail_Rate,
	  ROUND(100.0*SUM(CASE WHEN Inspection_results = 'Pending' THEN 1 END)/COUNT(*),2) AS Pending_Rate
	  FROM supply_chain_data
	  GROUP BY Supplier_name
	  )
SELECT *,
		CASE WHEN Pass_Rate >= 70 THEN 'Excellent'
		     WHEN Pass_Rate >= 50 AND Pass_Rate < 70 THEN 'Good'
			 WHEN Pass_Rate >= 30 AND Pass_Rate < 50 THEN 'Average'
			 ELSE 'Poor' END AS Overall_Supplier_Quality
		FROM Supplier_stats

--Business Requirement,Warehouse Inventory Health Report,For each warehouse, produce:Warehouse Name,
--Total SKUs stored,Total Inventory Units,Inventory Value,Number of Low Stock SKUs,Number of Out-of-Stock SKUs,
--% of Low Stock SKUs,Inventory Health
WITH SKU AS
(
SELECT 
     Supplier_name,
     SKU,
     SUM(Stock_levels) AS SKU_counts
     FROM supply_chain_data
     GROUP BY Supplier_name,SKU
     ),
Stocks AS
(
 SELECT *,
        CASE WHEN SKU_counts = 0 THEN 'Out Of Stock'
             WHEN SKU_counts > 0 AND SKU_counts <= 20 THEN 'Low Stock'
             ELSE 'Healthy' END AS Stock_report
             FROM SKU
             ),
SKU_report AS
(
SELECT Supplier_name,
       COUNT(CASE WHEN Stock_report = 'Low Stock' THEN 1 END) AS No_Of_Low_Stock_SKUs,
       COUNT(CASE WHEN Stock_report = 'Out Of Stock' THEN 1 END) AS No_Of_Out_of_Stock_SKUs,
       ROUND(100.0*COUNT(CASE WHEN Stock_report = 'Low Stock' THEN 1 END)/COUNT(SKU_counts),2) AS Low_SKU_perc
       FROM Stocks
       GROUP BY Supplier_name
       ),
Suppliers AS
(
SELECT
	  Supplier_name,
	  SUM(Availability+Number_of_products_sold) AS SKUs_Stored,
	  SUM(Stock_levels) AS Inventory_Units,
	  ROUND(SUM(Stock_levels*Price),2) AS Inventory_Value
	  FROM supply_chain_data
	  GROUP BY Supplier_name
	  ),
Supplier_Summary AS
(
SELECT 
       s.Supplier_name,
       s.SKUs_Stored,
       s.Inventory_Units,
       s.Inventory_Value,
       sk.No_Of_Low_Stock_SKUs,
       sk.Low_SKU_perc,
       sk.No_Of_Out_of_Stock_SKUs
       FROM Suppliers s JOIN SKU_report sk ON
       s.Supplier_name = sk.Supplier_name
       )
SELECT *,
       CASE WHEN Low_SKU_perc <= 15 THEN 'Healthy'
            WHEN Low_SKU_perc > 15 AND Low_SKU_perc <= 25 THEN 'Warning'
            ELSE 'Critical' END AS Inventory_Health
       FROM Supplier_Summary


--Supplier Revenue Concentration.For every supplier, determine whether their revenue is concentrated in a small number of SKUs.
--Return:Supplier Name,Total Revenue,Revenue from Top 3 SKUs,% Revenue contributed by Top 3 SKUs,Concentration Segment
WITH Supplier_SKU_Revenue AS
(SELECT 
      Supplier_name,
      SKU,
      ROUND(SUM(Revenue_generated),0) AS SKU_Revenue
      FROM supply_chain_data
      GROUP BY Supplier_name,SKU),
top_sku AS
(SELECT *,
        DENSE_RANK() OVER(PARTITION BY Supplier_name ORDER BY SKU_Revenue DESC) AS rn
        FROM Supplier_SKU_Revenue),
top3sku_revenue AS
(SELECT Supplier_name,
        SUM(SKU_Revenue) AS Total_Revenue,
        SUM(CASE WHEN rn <= 3 THEN SKU_Revenue END) AS Top3_SKU_Revenue,
        ROUND(100*SUM(CASE WHEN rn <= 3 THEN SKU_Revenue END)/SUM(SKU_Revenue),2) AS Top3_SKU_Revenue_Perc
        FROM top_sku
        GROUP BY Supplier_name)
SELECT *,
       CASE WHEN Top3_SKU_Revenue_Perc >= 80 THEN 'Highly Concentrated'
            WHEN Top3_SKU_Revenue_Perc >= 60 AND Top3_SKU_Revenue_Perc < 80 THEN 'Moderately Concentrated'
            ELSE 'Diversified' END AS Concentration_Segement
       FROM top3sku_revenue


--Which transportation mode delivers the best balance of logistics cost and product quality
SELECT Transportation_modes,
       COUNT(SKU) AS SKUs_Carried,
       COUNT(DISTINCT Routes) AS No_Of_Routes,
       AVG(Shipping_times) AS Avg_Shipping_Times,
       COUNT(Supplier_name) AS Total_Suppliers, 
       ROUND(SUM(Costs),0) AS Total_Costs,
       ROUND(100.0*SUM(Costs)/SUM(Revenue_generated),2) AS Revenue_Margin,
       ROUND(AVG(Defect_rates),2) AS Avg_Defect_Rates,
       ROUND(100.0*COUNT(CASE WHEN Inspection_results = 'Pass' THEN 1 END)/COUNT(*),2) AS Passed_Rate,
       ROUND(100.0*COUNT(CASE WHEN Inspection_results = 'Fail' THEN 1 END)/COUNT(*),2) AS Failed_Rate,
       ROUND(100.0*COUNT(CASE WHEN Inspection_results = 'Pending' THEN 1 END)/COUNT(*),2) AS Pending_Rate
       FROM supply_chain_data
       GROUP BY Transportation_modes

--Which supplier delivers the best balance of revenue, quality, and cost:Total Revenue,Total Profit,Profit Margin,
--Average Defect Rate,Inspection Pass Rate,Average Manufacturing Cost,Revenue per SKU,SKU Count

SELECT Supplier_name,
       ROUND(SUM(Revenue_generated),0) AS Total_Revenue,
       ROUND(SUM(Revenue_generated - Costs - Manufacturing_costs - Shipping_costs),0) AS Total_Profit,
       ROUND(100*SUM(Revenue_generated - Costs - Manufacturing_costs - Shipping_costs)/SUM(Revenue_generated),2) AS Profit_Margin,
       ROUND(AVG(Defect_rates),2) AS Avg_Defect_Rate,
       ROUND(100*COUNT(CASE WHEN Inspection_results = 'Pass' THEN 1 END)/COUNT(*),2) AS Inspection_Pass_Rate,
       ROUND(AVG(Manufacturing_costs),2) AS Avg_Manufacturing_Cost,
       ROUND(SUM(Revenue_generated)/COUNT(*),0) AS Revenue_Per_SKU,
       COUNT(SKU) AS SKU_Count
       FROM supply_chain_data
       GROUP BY Supplier_name
