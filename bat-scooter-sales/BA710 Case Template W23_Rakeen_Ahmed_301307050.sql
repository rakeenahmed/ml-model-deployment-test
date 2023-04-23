
/***BE SURE TO DROP ALL TABLES IN WORK THAT BEGIN WITH "CASE_"***/


/*Set Time Zone*/
set time_zone='-4:00';
select now();

select now();

use ba710case;

/***PRELIMINARY ANALYSIS***/

select * from ba710case.ba710_emails;
select * from ba710_prod;
select * from ba710_sales;

/*Create a VIEW in WORK called CASE_SCOOT_NAMES that is a subset of the prod table
which only contains scooters.
Result should have 7 records.*/


create view work.case_scoot_names as
select * from ba710_prod 
where product_type = 'scooter';

select * from work.case_scoot_names;


/*The following code uses a join to combine the view above with the sales information.
  Can the expected performance be improved using an index?
  A) Calculate the EXPLAIN COST.
  B) Create the appropriate indexes.
  C) Calculate the new EXPLAIN COST.
  D) What is your conclusion?:
*/

create table work.case_scoot_sales as 
	select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    
select * from work.case_scoot_sales;

/*A) Calculate the EXPLAIN Cost*/

explain format = json select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
/*
{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "4382.61"
*/


/*B) Create the appropriate INDEXES*/

create index idx_productid on ba710case.ba710_sales (product_id);

/* C) Calculate the new EXPLAIN COST.*/

explain format = json select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;

/*
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "597.09"
*/

/*D) What is your conclusion?:Ans.Creating the index drastically reduces the query cost from 4382.61 to 597.09*/


/***PART 1: INVESTIGATE BAT SALES TRENDS***/  
    
/*The following creates a table of daily sales and will be used in the following step.*/

CREATE TABLE work.case_daily_sales AS
	select p.model, p.product_id, date(s.sales_transaction_date) as sale_date, 
		   round(sum(s.sales_amount),2) as daily_sales
	from ba710case.ba710_sales as s 
    inner join ba710case.ba710_prod as p
		on s.product_id=p.product_id
    group by date(s.sales_transaction_date),p.product_id,p.model;

select * from work.case_daily_sales;

/*Examine the drop in sales.*/
/*Create a table of cumulative sales figures for just the Bat scooter from
the daily sales table you created.
Using the table created above, add a column that contains the cumulative
sales amount (one row per date).
Hint: Window Functions, Over. Should look like the first table in the word document(until cumulative_sales column*/


create table work.case_cumulative_sales_bat as
select *, sum(daily_sales) over(order by sale_date) as cumulative_sales
from work.case_daily_sales
where model = 'Bat';

/*Using the table above, create a VIEW that computes the cumulative sales 
for the previous 7 days for just the Bat scooter. 
(i.e., running total of sales for 7 rows inclusive of the current row.)
This is calculated as the 7 day lag of cumulative sum of sales
(i.e., each record should contain the sum of sales for the current date plus
the sales for the preceeding 6 records).
*/

select * from work.case_cumulative_sales_bat;

create view work.case_7day_sales as
select *, sum(daily_sales) over (rows between 6 preceding and current row) as seven_day_cumulative_sales
from work.case_cumulative_sales_bat;

select * from work.case_7day_sales;

/*Using the view you just created, create a new view that calculates
the weekly sales growth as a percentage change of cumulative sales
compared to the cumulative sales from the previous week (seven days ago).

See the Word document for an example of the expected output for the Blade scooter.*/

create view work.weekly_sales_growth as 
select *, ((cumulative_sales - lag(cumulative_sales,7) over()) / lag(cumulative_sales,7) over()) *100 as pct_weekly_growth
from work.case_7day_sales;

select * from work.weekly_sales_growth;


/*Questions: On what date does the cumulative weekly sales growth drop below 10%?
Answer: 2016-12-05 */       

select sale_date,pct_weekly_growth from work.weekly_sales_growth
where pct_weekly_growth < 10
limit 1;

/*Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer: 56 days*/

select datediff('2016-12-05','2016-10-10');

/*********************************************************************************************
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the Bat Limited Edition.
*/

select distinct(model) from ba710_prod;

-- Create cumulative sales table for only Bat Limited Edition
create table work.case_cumulative_sales_bat_limited_edition as
select *, sum(daily_sales) over(order by sale_date) as cumulative_sales
from work.case_daily_sales
where model = 'Bat Limited Edition';

select * from work.case_cumulative_sales_bat_limited_edition;

-- Create 7 day cumulative sales table for Bat Limited Edition
create view work.case_7day_sales_bat_limited_edition as
select *, sum(daily_sales) over (rows between 6 preceding and current row) as seven_day_cumulative_sales
from work.case_cumulative_sales_bat_limited_edition;

select * from work.case_7day_sales_bat_limited_edition;

-- Create weekly sales growth table for Bat Limited Edition
create view work.weekly_sales_growth_bat_limited_edition as 
select *, ((cumulative_sales - lag(cumulative_sales,7) over()) / lag(cumulative_sales,7) over()) *100 as pct_weekly_growth
from work.case_7day_sales_bat_limited_edition;

select * from work.weekly_sales_growth_bat_limited_edition;

-- On what date does the cumulative sales growth drop below 10%?
-- Ans: 2017-04-29
select sale_date,pct_weekly_growth from work.weekly_sales_growth_bat_limited_edition
where pct_weekly_growth < 10
limit 1;

-- How many days since the launch date did it take for cumulative sales growth to drop below 10%?
-- Ans: 73 days
select datediff('2017-04-29','2017-02-15');

/*********************************************************************************************
However, the Bat Limited was at a higher price point.
Let's take a look at the 2013 Lemon model, since it's a similar price point.  
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the 2013 Lemon model.*/

-- Create cumulative sales table for only Lemon model scooter
create table work.case_cumulative_sales_lemon as
select *, sum(daily_sales) over(order by sale_date) as cumulative_sales
from work.case_daily_sales
where model = 'Lemon';

select * from work.case_cumulative_sales_lemon;

-- Create 7 day cumulative sales table for Lemon
create view work.case_7day_sales_lemon as
select *, sum(daily_sales) over (rows between 6 preceding and current row) as seven_day_cumulative_sales
from work.case_cumulative_sales_lemon;

-- Create weekly sales growth table for Lemon 
create view work.weekly_sales_growth_lemon as 
select *, ((cumulative_sales - lag(cumulative_sales,7) over()) / lag(cumulative_sales,7) over()) *100 as pct_weekly_growth
from work.case_7day_sales_lemon;

select * from work.weekly_sales_growth_lemon;

-- On what date does the cumulative sales growth drop below 10%?
-- Ans: 2010-06-11
select sale_date,pct_weekly_growth from work.weekly_sales_growth_lemon
where pct_weekly_growth < 10
limit 1;

-- How many days since the launch date did it take for cumulative sales growth to drop below 10%?
-- Ans: 93 days
select datediff('2010-06-11','2010-03-10');


/*Case Part 2*/

/*1. Replicate your cumulative sales analysis in Case Part 1 using stored procedures for the repetitive analysis (where you likely employed copy/paste earlier).  Note: Your Part 1 analysis should be replicated perfectly.  If your results initially didn’t match the table below, your Part 2 results should match what you previously created.
Create a stored procedure that generates the cumulative analysis table for any product by passing it a parameter value for product id.  Run your stored procedure on products 3, 7 and 8.
*/

-- Create cumulative sales table for only Lemon model scooter
create table work.case_p2_cumulative_sales as 
select *, sum(daily_sales) over(order by sale_date) as cumulative_sales
from work.case_daily_sales
where product_id = product_id_param;

-- Create 7 day cumulative sales table for Lemon
create view work.case_p2_7day_sales as 
select *, sum(daily_sales) over (rows between 6 preceding and current row) as seven_day_cumulative_sales
from work.case_p2_cumulative_sales; 

-- Create weekly sales growth table for Lemon 
create view work.case_p2_weekly_sales_growth_ as
select *, ((cumulative_sales - lag(cumulative_sales,7) over()) / lag(cumulative_sales,7) over()) *100 as pct_weekly_growth
from work.case_p2_cumulative_sales; 

select * from work.case_p2_weekly_sales_growth; 

/*Stored Procedure Code*/

drop procedure if exists work.pct_weekly_growth;

delimiter //

create procedure work.pct_weekly_growth(product_id_param int)
begin
-- Create cumulative sales table for only Lemon model scooter
drop table if exists work.case_p2_cumulative_sales;
create table work.case_p2_cumulative_sales as 
select *, sum(daily_sales) over(order by sale_date) as cumulative_sales
from work.case_daily_sales
where product_id = product_id_param;

-- Create 7 day cumulative sales table for Lemon
create or replace view work.case_p2_7day_sales as 
select *, sum(daily_sales) over (rows between 6 preceding and current row) as seven_day_cumulative_sales
from work.case_p2_cumulative_sales; 

-- Create weekly sales growth table for Lemon 
create or replace view work.case_p2_weekly_sales_growth as
select *, ((cumulative_sales - lag(cumulative_sales,7) over()) / lag(cumulative_sales,7) over()) *100 as pct_weekly_growth
from work.case_p2_7day_sales; 

select * from work.case_p2_weekly_sales_growth; 

end //
delimiter ;

call work.pct_weekly_growth(5);
call work.pct_weekly_growth(3);
call work.pct_weekly_growth(7);
call work.pct_weekly_growth(8);
