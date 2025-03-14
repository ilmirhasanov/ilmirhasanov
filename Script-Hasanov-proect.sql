/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Хасанов Ильмир
 * Дата: 29.10.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
	
-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
WITH user_stat AS(
SELECT COUNT(u.id) AS total_user,
(SELECT COUNT(id) AS total_pay_user
FROM fantasy.users
WHERE payer = 1)
FROM fantasy.users AS u)
SELECT *,
total_pay_user::numeric / total_user::numeric AS proportion_of_users
FROM user_stat;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
WITH user_stat AS(SELECT r.race,
	COUNT(u.id) AS total_user,
	SUM(u.payer) AS total_pay_user,
	SUM(u.payer)::NUMERIC / COUNT(u.id)::NUMERIC AS proportion_of_users
FROM fantasy.users AS u
	LEFT JOIN fantasy.race AS r USING (race_id)
	GROUP BY race)
SELECT *
FROM user_stat
ORDER BY proportion_of_users DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT COUNT(amount) AS total_amount,
	SUM(amount) AS total_sum,
	MIN(amount) AS MIN_amount,
	MAX(amount) AS MAX_amount,
	AVG(amount) AS AVG_amount,
	percentile_disc(0.50) WITHIN GROUP(ORDER BY amount) AS mediana,
	stddev(amount) AS stand_otclon
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT COUNT(transaction_id) AS total_transaction,
	(SELECT COUNT(transaction_id) AS null 
	FROM fantasy.events 
	WHERE amount = 0),
	(SELECT COUNT(transaction_id) AS null 
	FROM fantasy.events 
	WHERE amount = 0)::NUMERIC / COUNT(transaction_id)::NUMERIC AS proportion 
FROM fantasy.events;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
WITH
pay_users AS (
	SELECT u.id,
	u.payer,
	COUNT(e.transaction_id) AS total_transaction,
	SUM(e.amount) AS total_amount
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u USING (id)
WHERE amount <> 0
GROUP BY u.id, u.payer
)
SELECT CASE WHEN payer = 1 THEN 'pay_user' ELSE 'not_pay_user' END AS pay_or_not_pay,
	COUNT(id) AS total_user,
	AVG(total_transaction) AS AVG_count_transaction,
	AVG(total_amount) AS AVG_sum_amount
FROM pay_users
GROUP BY payer;

-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH stat AS(
SELECT game_items,
	COUNT(e.transaction_id) AS total_count_per_item,
	COUNT(e.id) AS total_users,
	COUNT(DISTINCT e.id) AS count_user_id
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
WHERE amount <> 0
GROUP BY game_items
)
SELECT *,
	total_count_per_item / SUM(total_count_per_item) OVER() AS proportion_count_per_items,
	count_user_id::numeric / total_users::numeric AS proportion_count_user_id
FROM stat
ORDER BY total_count_per_item DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH user_stat AS (
SELECT r.race,
	COUNT(DISTINCT e.id) - COUNT(*) FILTER (WHERE amount = 0) AS total_gamepay_users,
	COUNT(DISTINCT u.id) AS total_users
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
LEFT JOIN fantasy.race AS r ON r.race_id = u.race_id
GROUP BY r.race
),
user_stat_pay AS (
SELECT race,
	COUNT(DISTINCT id) AS total_payer_per_race 
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
LEFT JOIN fantasy.race AS r ON r.race_id = u.race_id
WHERE u.payer = 1
GROUP BY race
),
for_avg AS (
SELECT id, race,
	COUNT(transaction_id) AS count_transaction_user,
	SUM(amount) AS amount_per_user
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
LEFT JOIN fantasy.race AS r ON r.race_id = u.race_id
WHERE amount <> 0
GROUP BY id, race
),
final_avg AS (
SELECT race,
	AVG(count_transaction_user) AS avg_transaction_per_user,
	AVG(amount_per_user/count_transaction_user) AS avg_per_one_user,
	AVG(amount_per_user) AS avg_sum_per_user
FROM for_avg
GROUP BY race
)
SELECT race,
	total_users,
	total_gamepay_users,
	total_gamepay_users::numeric / total_users::NUMERIC AS proportion_gamepay_users,
	total_payer_per_race::numeric / total_users::numeric AS proportion_pay_user,
	avg_transaction_per_user,
	avg_per_one_user,
	avg_sum_per_user
	--avg_sum_per_user / avg_transaction_per_user AS correct_avg_per_user
FROM user_stat
LEFT JOIN user_stat_pay USING (race)
LEFT JOIN final_avg USING (race)
ORDER BY avg_sum_per_user DESC;

-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь


