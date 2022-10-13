									-- Итоговая работа

								
-- Вопрос № 1 - В каких городах больше одного аэропорта?
															
select count(airport_code), city
from airports a
group by city
having count(airport_code) > 1

-- Можно было вывести еще столбец airport_name с помощью подзапроса или СТЕ, 
-- но я сделал запрос максимально коротким, чтобы получить что нужно и не более.


-- Вопрос № 2 - В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? (Подзапрос)

-- Логика: сначала в подзапросе вывел тип самолета с мах. дальностью полета, затем соединил таблицы flights и airports для 
-- получения названия аэропорта и соответственно cгруппировал

select a.airport_name
from 
	(select aircraft_code
	from aircrafts
	order by "range" desc
	limit 1) d
join flights f on f.aircraft_code = d.aircraft_code
join airports a on a.airport_code = f.departure_airport 
group by 1


-- Вопрос № 3 - Вывести 10 рейсов с максимальным временем задержки вылета (Оператор LIMIT)

-- Логика: С помощью функции интервал вычислил разницу м/у фактич.и плановым вылетом, затем по условию убрал пустые строки,
-- отсортировал по убыванию и оставил 10 первых записей

select flight_no "№ рейса", actual_departure - scheduled_departure as "Время задержки"
from flights f
where actual_departure is not null 
order by 2 desc 
limit 10


-- Вопрос № 4 - Были ли брони, по которым не были получены посадочные талоны? (Верный тип JOIN)

-- Логика: Соединил таблицы tickets и boarding_passes по общему знаменателю чтобы получить все данные из tickets и
-- совпадающие в boarding_passes , затем по условию отфильтровал boarding_no по строкам соответствующим NULL

select count(t.book_ref) as "Брони без посад.талонов"
from tickets t 
left join boarding_passes bp on bp.ticket_no = t.ticket_no
where bp.boarding_no is null


-- Вопрос № 5 - Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете. 
-- Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
-- Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более 
-- ранних рейсах в течении дня (Оконная функция; подзапросы или/и cte)

-- Логика: свободные места - это те на которые не было выдано посадочных талонов. В первом подзапросе получаем колич.посад.талонов, 
-- во втором получаем колич.мест и выводим разницу - получаем колич.свободных мест и считаем отношение в %. 
-- Далее через ОФ получаем накопительный итог на каждый день(приводим к формату DATE) по каждому аэропорту

select  f.flight_id, f.scheduled_departure, f.actual_departure, f.departure_airport, "Количество мест", 
	"Количество мест" - "Количество посад.талонов" as "Колич.свободных мест", 
		round(("Количество мест" - "Количество посад.талонов") / "Количество мест" :: numeric, 2) * 100 as "% отношение к общему", 
		sum("Количество посад.талонов") over (partition by (f.departure_airport, f.actual_departure :: date) 
		order by f.actual_departure) as "Накопительный итог"
	from 
	(select flight_id, count(boarding_no) as "Количество посад.талонов"
		from boarding_passes bp
		group by 1) as d
	join flights f on f.flight_id = d.flight_id
	join
		(select aircraft_code, count(seat_no) as "Количество мест"
		from seats s 
		group by 1) as d1 on d1.aircraft_code = f.aircraft_code
        
	
-- Вопрос № 6 - Найдите процентное соотношение перелетов по типам самолетов от общего количества (Подзапрос или окно; оператор ROUND)

-- Логика: в подзапросе вывел общее колич. строк по столбцу f.flight_id сгруппированное по коду самолета и 
-- поделил на общее колич. строк f.flight_id. Условие where - чтобы были только совершенные рейсы. Далее группировка по коду самолета

select 
	a.model as "Модель самолета",
	round(count(f.flight_id) /
		(select 
			count(f.flight_id)
		from flights f 
		where f.actual_departure is not null
		) :: numeric * 100) as "% от общего числа"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_departure is not null
group by a.aircraft_code 


-- Вопрос № 7 - Были ли города, в которые можно добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета? (CTE)		

-- Логика: в СТЕ получил мах стоимость по эконому, мин по бизнес тарифу. Сгруппировал по городу вылета и городу прилета и классу перелета.
-- Во внешнем запросе фильтруем по условию max(d_amount_max) > min(t_amount_min)

with cte1 as 
	(select a.city A, a2.city B, tf.fare_conditions,
		case when tf.fare_conditions  = 'Economy' then max(tf.amount) end d_amount_max,
		case when tf.fare_conditions  = 'Business' then min(tf.amount) end t_amount_min
	from ticket_flights tf
	join flights f on f.flight_id = tf.flight_id 
	join airports a on a.airport_code = f.departure_airport 
	join airports a2 on f.arrival_airport = a2.airport_code 
	group by a.city, a2.city, tf.fare_conditions)
select A "город вылета", B "город прилета"
from cte1
group by A, B
having max(d_amount_max) > min(t_amount_min)


-- Вопрос № 8 - Между какими городами нет прямых рейсов? (Декартово произведение в предложении FROM; 
-- самостоятельно созданные представления; оператор EXCEPT)

-- Логика: во временной таблице получил города м/у которыми есть рейсы, с помощью JOIN получил город отправления и прибытия,
-- в основном запросе использовал декартово произведение для получения всех городов с условием их неравенства
-- оператор EXCEPT - чтобы убрать данные которые есть в сте1

create view question_8 as
with cte1 as 
	(select distinct 
		a.city "аэропорт отправления",
		a2.city "аэропорт прибытия"
	from flights f 
	join airports a on a.airport_code = f.departure_airport  
	join airports a2 on a2.airport_code = f.arrival_airport)
select distinct 
		a.city "аэропорт отправления",
		a2.city "аэропорт прибытия"
	from airports a, airports a2 
	where a.city != a2.city
except select *
from cte1


-- Вопрос № 9 - Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
-- сравните с допустимой максимальной дальностью перелетов в самолетах, обслуживающих эти рейсы 
--(Оператор RADIANS или использование sind/cosd; CASE)

-- Логика: Соединил два раза таблицу airport. Для вычисления расстояния использовал формулу из задания и оператор  RADIANS чтобы 
-- преобразовать градусы в радианы. Далее с помощью case сравнил расстояние и дальность полета самолета

select distinct 
		a."range" "Мах.дальность полета", 
		a1.airport_name "Аэропорт вылета",
		a2.airport_name "Аэропорт прибытия",
		round(radians(acos(sin(a1.latitude) * sin(a2.latitude) + cos(a1.latitude) * cos(a2.latitude) * 
		cos(a1.longitude - a2.longitude)) * 6371)::numeric,1) as "Расстояние м/у аэропортами",
	case when
		a."range" <
		radians(acos(sin(a1.latitude) * sin(a2.latitude) + cos(a1.latitude) * cos(a2.latitude) * cos(a1.longitude - a2.longitude))) * 6371
		then 'no'
		else 'yes'
		end "Долетит?"
from flights f 
join airports a1 on f.departure_airport = a1.airport_code
join airports a2 on f.arrival_airport = a2.airport_code
join aircrafts a on a.aircraft_code = f.aircraft_code



