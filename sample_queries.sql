-- Sample Queries

-- Display all active clients
SELECT * FROM active_clients;

-- Display a schedule for Monday
SELECT * FROM get_schedule_by_day('Monday');

-- Display trainers with best average rating
SELECT * FROM top_trainers_by_rating;

-- Display average rating of every trainer with number of received reviews
SELECT 
    t.trainer_id, 
    p.name AS trainer_name, 
    AVG(f.rating) AS average_rating, 
    COUNT(f.feedback_id) AS number_of_reviews
FROM trainer t
JOIN person p ON t.person_id = p.person_id
LEFT JOIN feedback f ON t.trainer_id = f.trainer_id
GROUP BY t.trainer_id, p.name
ORDER BY average_rating DESC;

-- Display number of each membership type being active
SELECT 
    m.name AS membership_type, 
    COUNT(pm.client_id) AS number_of_clients
FROM membership m
LEFT JOIN purchased_membership pm ON m.membership_id = pm.membership_id
WHERE pm.status = 'active' AND pm.valid_until >= GETDATE()
GROUP BY m.name
ORDER BY number_of_clients DESC;

-- Display a class that's the most popular (most reservations)
SELECT 
    c.name AS class_name, 
    COUNT(cb.booking_id) AS number_of_bookings
FROM class c
JOIN schedule s ON c.class_id = s.class_id
JOIN class_booking cb ON s.schedule_id = cb.schedule_id
WHERE cb.status = 'confirmed'
GROUP BY c.name
ORDER BY number_of_bookings DESC;


-- Display a attendance rate on classes
SELECT 
    c.name AS class_name, 
    COUNT(a.attendance_id) AS attended, 
    COUNT(cb.booking_id) AS booked, 
    ROUND((COUNT(a.attendance_id) * 100.0 / COUNT(cb.booking_id), 2) AS attendance_rate
FROM class c
JOIN schedule s ON c.class_id = s.class_id
JOIN class_booking cb ON s.schedule_id = cb.schedule_id
LEFT JOIN attendance a ON cb.booking_id = a.booking_id AND a.status = 'present'
GROUP BY c.name
ORDER BY attendance_rate DESC;
