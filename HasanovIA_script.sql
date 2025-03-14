/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Хасанов И.А.
 * Дата: 22.11.2024
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Напишите ваш запрос здесь
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),
-- Выведем объявления без выбросов и разделением на группы:
different_groups AS (
SELECT *, CASE WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
ELSE 'ЛенОбл'
END AS location_group,
CASE WHEN days_exposition BETWEEN 1 AND 31 THEN 'меньше месяца'
    WHEN days_exposition BETWEEN 32 AND 90 THEN 'меньше квартала'
    WHEN days_exposition BETWEEN 91 AND 180 THEN'меньше полугода'
    ELSE 'больше, чем полгода'
END AS duration,
last_price / total_area AS price_per_one
FROM real_estate.flats
LEFT JOIN real_estate.city AS c USING(city_id)
LEFT JOIN real_estate.advertisement AS a USING(id)
LEFT JOIN real_estate.type AS t USING(type_id)
WHERE id IN (SELECT * FROM filtered_id) AND type = 'город'
)
SELECT location_group, 
duration,
AVG(price_per_one) AS avg_price_per_one_metr,
AVG(total_area) AS AVG_area,
percentile_disc(0.50) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
percentile_disc(0.50) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
percentile_disc(0.50) WITHIN GROUP (ORDER BY floors_total) AS median_floors_total,
CASE WHEN location_group = 'Санкт-Петербург' THEN COUNT(id) / (SELECT COUNT(id) FROM different_groups WHERE location_group = 'Санкт-Петербург')::numeric
WHEN location_group = 'ЛенОбл' THEN COUNT(id) / (SELECT COUNT(id) FROM different_groups WHERE location_group = 'ЛенОбл')::numeric
END AS ratio
FROM different_groups
GROUP BY location_group, duration;


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Выведем статистику для открытых объявлений:
period_of_first_exposition AS (
SELECT RANK() OVER(ORDER BY COUNT(DISTINCT id) DESC) AS Rank_of_first_exposition,
EXTRACT (MONTH FROM first_day_exposition) AS month_of_exposition,
COUNT(DISTINCT id) AS amount_advertisements,
AVG(last_price / total_area) AS price_per_one_first_exposition,
AVG(total_area) AS avg_area_first_exposition
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a USING (id)
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NULL
GROUP BY EXTRACT (MONTH FROM first_day_exposition)
),
-- выведем статистику для закрытых объявлений
period_of_sales AS (
SELECT RANK() OVER(ORDER BY COUNT(DISTINCT id) DESC) AS Rank_of_sales,
EXTRACT (MONTH FROM first_day_exposition) AS month_of_exposition,
COUNT(DISTINCT id) AS amount_sales,
AVG(last_price / total_area) AS price_per_one_of_sales,
AVG(total_area) AS avg_area_of_sales
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a USING (id)
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL
GROUP BY EXTRACT (MONTH FROM first_day_exposition)
)
SELECT *
FROM period_of_first_exposition AS e
JOIN period_of_sales AS s ON e.month_of_exposition = s.month_of_exposition;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Анализ рынка недвижимости Ленобласти
analize_LenObl as (
SELECT city,
COUNT (id) AS total_amount,
COUNT(id) FILTER (WHERE days_exposition IS NULL) AS amount_advertisements,
COUNT(id) FILTER (WHERE days_exposition IS NOT NULL) AS total_amount_sales,
(COUNT(id) FILTER (WHERE days_exposition IS NOT NULL) / COUNT(id)::numeric) AS ratio_amount_sales,
AVG(last_price / total_area) AS price_per_one,
AVG(total_area) AS avg_area,
AVG(days_exposition) AS avg_exposition
FROM real_estate.flats AS f
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.type AS t USING (type_id)
LEFT JOIN real_estate.advertisement AS a USING(id)
WHERE id IN (SELECT * FROM filtered_id)
AND city <> 'Санкт-Петербург'
GROUP BY city
HAVING (COUNT(id) FILTER (WHERE days_exposition IS NULL) + COUNT(id) FILTER (WHERE days_exposition IS NOT NULL)) > 50
ORDER BY ratio_amount_sales DESC
LIMIT 15
)
SELECT *
FROM analize_LenObl;






