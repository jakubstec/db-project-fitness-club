
--1.
CREATE VIEW vw_active_clients AS
SELECT c.client_id, p.name, p.email, p.phone, pm.valid_until
FROM client c
JOIN person p ON c.person_id = p.person_id
JOIN purchased_membership pm ON c.client_id = pm.client_id
WHERE pm.status = 'active' AND pm.valid_until >= GETDATE();

--2. (function)
CREATE FUNCTION fun_get_schedule_by_day (@week_day NVARCHAR(20))
RETURNS TABLE
AS
RETURN (
    SELECT s.schedule_id, 
           cl.name AS class_name, 
           p.name AS trainer_name,
           s.room, 
           s.start_time, 
           s.end_time
    FROM schedule s
    JOIN class cl ON s.class_id = cl.class_id
    JOIN trainer t ON s.trainer_id = t.trainer_id
    JOIN person p ON t.person_id = p.person_id
    WHERE s.week_day = @week_day
);

--3.
CREATE VIEW vw_average_attendance_by_category AS
SELECT cl.category, 
       SUM(cl.max_participants) AS total_slots,
       COUNT(cb.booking_id) AS total_booked,
       COUNT(a.attendance_id) AS total_attended,
       ROUND((COUNT(a.attendance_id) * 100.0 / SUM(cl.max_participants)),2) AS attendance_rate
FROM class cl
JOIN schedule s ON cl.class_id = s.class_id
JOIN class_booking cb ON s.schedule_id = cb.schedule_id
LEFT JOIN attendance a ON cb.booking_id = a.booking_id AND a.status = 'present'
GROUP BY cl.category

--4.
CREATE VIEW vw_top_trainers_by_rating AS
SELECT t.trainer_id, p.name AS trainer_name, AVG(f.rating) AS average_rating
FROM trainer t
JOIN person p ON t.person_id = p.person_id
JOIN feedback f ON t.trainer_id = f.trainer_id
GROUP BY t.trainer_id, p.name
ORDER BY average_rating DESC;

--5.
CREATE VIEW vw_clients_with_expiring_memberships AS
WITH expiring_memberships AS (
    SELECT c.client_id, p.name AS client_name, pm.valid_until
    FROM client c
    JOIN person p ON c.person_id = p.person_id
    JOIN purchased_membership pm ON c.client_id = pm.client_id
    WHERE pm.valid_until BETWEEN GETDATE() AND DATEADD(DAY, 7, GETDATE())
)
SELECT client_id, client_name, valid_until
FROM expiring_memberships;

--6.
CREATE VIEW vw_membership_revenue_by_month AS
SELECT YEAR(pm.purchase_date) AS year, MONTH(pm.purchase_date) AS month, SUM(m.base_price) AS total_revenue
FROM purchased_membership pm
JOIN membership m ON pm.membership_id = m.membership_id
GROUP BY YEAR(pm.purchase_date), MONTH(pm.purchase_date)

--7.
CREATE VIEW vw_equipment_needing_maintenance AS
SELECT e.equipment_id, e.name, e.manufacturer, e.purchase_date, e.status
FROM equipment e
WHERE e.status = 'requires_maintenance';


--8.
CREATE VIEW vw_TrainerPerformance AS
SELECT 
    p.name AS trainer_name,
    t.specialisation,
    COUNT(DISTINCT s.schedule_id) AS total_classes,
    COUNT(DISTINCT cb.booking_id) AS total_bookings,
    AVG(CAST(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END AS FLOAT)) AS avg_attendance_rate
FROM trainer t
JOIN person p ON t.person_id = p.person_id
JOIN schedule s ON t.trainer_id = s.trainer_id
LEFT JOIN class_booking cb ON s.schedule_id = cb.schedule_id
LEFT JOIN attendance a ON cb.booking_id = a.booking_id
GROUP BY p.name, t.specialisation;

--9.
CREATE VIEW vw_top_attending_clients AS
SELECT 
    c.client_id, 
    p.name AS client_name, 
    COUNT(a.attendance_id) AS total_attendances
FROM client c
JOIN person p ON c.person_id = p.person_id
JOIN class_booking cb ON c.client_id = cb.client_id
JOIN attendance a ON cb.booking_id = a.booking_id
WHERE a.status = 'present'
GROUP BY c.client_id, p.name

--10.
CREATE VIEW vw_longest_membership_clients AS
SELECT 
    c.client_id, 
    p.name AS client_name, 
    DATEDIFF(DAY, c.join_date, GETDATE()) AS membership_duration_days
FROM client c
JOIN person p ON c.person_id = p.person_id