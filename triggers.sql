-- Triggers

--1.
CREATE TRIGGER trg_check_class_capacity
ON class_booking
AFTER INSERT
AS
BEGIN
    DECLARE @max_participants INT;
    DECLARE @current_bookings INT;

    SELECT @max_participants = c.max_participants,
           @current_bookings = COUNT(cb.booking_id)
    FROM class c
    JOIN schedule s ON c.class_id = s.class_id
    JOIN class_booking cb ON s.schedule_id = cb.schedule_id
    WHERE cb.schedule_id IN (SELECT schedule_id FROM inserted)
    GROUP BY c.max_participants;

    IF @current_bookings > @max_participants
    BEGIN
	THROW 50010, 'The maximum number of participants for this class has been exceeded.', 1;
        ROLLBACK TRANSACTION;
    END
END;

--2.
CREATE TRIGGER trg_cancel_bookings_after_membership_expiry
ON purchased_membership
AFTER UPDATE
AS
BEGIN
    IF UPDATE(valid_until)
    BEGIN
        UPDATE cb
        SET cb.status = 'cancelled'
        FROM class_booking cb
        JOIN inserted i ON cb.client_id = i.client_id
        WHERE i.valid_until < GETDATE();
    END
END;

--3.
CREATE TRIGGER trg_auto_set_membership_validity
ON purchased_membership
AFTER INSERT
AS
BEGIN
    UPDATE pm
    SET pm.valid_until = DATEADD(DAY, m.duration_days, pm.purchase_date)
    FROM purchased_membership pm
    JOIN inserted i ON pm.purchased_membership_id = i.purchased_membership_id
    JOIN membership m ON pm.membership_id = m.membership_id;
END;

--4.
CREATE TRIGGER trg_prevent_class_overlap
ON schedule
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN schedule s ON s.room = i.room
        WHERE s.schedule_id != i.schedule_id
        AND (
            (i.start_time BETWEEN s.start_time AND s.end_time)
            OR (i.end_time BETWEEN s.start_time AND s.end_time)
        )
    )
    BEGIN
		THROW 50020, 'Class time overlaps with existing schedule', 1;
        ROLLBACK TRANSACTION;
    END
END;

--5.
CREATE TRIGGER trg_update_class_status_after_booking
ON class_booking
AFTER INSERT
AS
BEGIN
    DECLARE @schedule_id INT;
    DECLARE @max_participants INT;
    DECLARE @current_bookings INT;

    SELECT @schedule_id = i.schedule_id FROM inserted i;

    SELECT @max_participants = c.max_participants
    FROM schedule s
    JOIN class c ON s.class_id = c.class_id
    WHERE s.schedule_id = @schedule_id;

    SELECT @current_bookings = COUNT(*)
    FROM class_booking
    WHERE schedule_id = @schedule_id;

    IF @current_bookings >= @max_participants
    BEGIN
        UPDATE schedule
        SET status = 'full'
        WHERE schedule_id = @schedule_id;
    END
END;

-- Indexes

CREATE INDEX IX_Trainers_Specialization
ON trainer(specialisation);

CREATE INDEX IX_Schedule_ClubDayTime
ON schedule(room, week_day, start_time);

CREATE INDEX IX_Clients_JoinDate
ON client(join_date);

CREATE INDEX IX_Equipment_Status
ON equipment(status);

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
