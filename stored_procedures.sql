
-- Stored Procedures

-- 1.
CREATE PROCEDURE sp_add_client
    @name NVARCHAR(100),
    @email NVARCHAR(100),
    @phone NVARCHAR(20),
    @birth_date DATE,
    @join_date DATE,
    @status NVARCHAR(50),
    @membership_id INT
AS
BEGIN
    DECLARE @person_id INT;
    DECLARE @client_id INT;

    INSERT INTO person (name, email, phone, birth_date)
    VALUES (@name, @email, @phone, @birth_date);

    SET @person_id = SCOPE_IDENTITY();

    INSERT INTO client (person_id, join_date, status)
    VALUES (@person_id, @join_date, @status);

    SET @client_id = SCOPE_IDENTITY();

    INSERT INTO purchased_membership (client_id, membership_id, purchase_date, valid_until, status)
    SELECT 
        @client_id, 
        @membership_id, 
        GETDATE(), 
        DATEADD(DAY, m.duration_days, GETDATE()), 
        'active'
    FROM membership m
    WHERE m.membership_id = @membership_id;
END;

--2.
CREATE PROCEDURE sp_BookClass
    @client_id INT,
    @schedule_id INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 
            FROM purchased_membership 
            WHERE client_id = @client_id 
              AND valid_until >= GETDATE() 
              AND status = 'active'
        )
        BEGIN
            THROW 50001, 'Client has no active membership.', 1;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM schedule 
            WHERE schedule_id = @schedule_id
        )
        BEGIN
            THROW 50003, 'The specified class schedule does not exist.', 1;
        END

        DECLARE @available_spots INT;
        SELECT @available_spots = c.max_participants - COUNT(cb.booking_id)
        FROM schedule s
        JOIN class c ON s.class_id = c.class_id
        LEFT JOIN class_booking cb ON s.schedule_id = cb.schedule_id AND cb.status = 'confirmed'
        WHERE s.schedule_id = @schedule_id
        GROUP BY c.max_participants;

        IF @available_spots <= 0
        BEGIN
            THROW 50002, 'No available slots for this class.', 1;
        END

        DECLARE @booking_id INT;
        INSERT INTO class_booking (client_id, schedule_id, booking_date, status)
        VALUES (@client_id, @schedule_id, GETDATE(), 'confirmed');

        SET @booking_id = SCOPE_IDENTITY();

        INSERT INTO attendance (booking_id, attendance_date, status)
        VALUES (@booking_id, NULL, 'absent');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;

--3.
CREATE PROCEDURE sp_CancelBooking
    @booking_id INT
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM class_booking 
        WHERE booking_id = @booking_id 
        AND status = 'confirmed'
    )
    BEGIN
        THROW 50003, 'Reservation does not exist or is already cancelled.', 1;
        RETURN;
    END

    DELETE FROM attendance
    WHERE booking_id = @booking_id;

    UPDATE class_booking
    SET status = 'cancelled'
    WHERE booking_id = @booking_id;
END;

--4.
CREATE PROCEDURE sp_MarkAttendance
    @booking_id INT,
    @attendance_status NVARCHAR(50)
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM class_booking 
        WHERE booking_id = @booking_id
    )
    BEGIN
        THROW 50004, 'Reservation does not exist.', 1;
        RETURN;
    END

    UPDATE attendance
    SET status = @attendance_status,
        attendance_date = GETDATE()
    WHERE booking_id = @booking_id;
END;

--5.
CREATE PROCEDURE sp_LeaveFeedback
    @client_id INT,          
    @trainer_id INT,         
    @rating DECIMAL(3, 2),   
    @comment NVARCHAR(255) = NULL 
AS
BEGIN
    IF @rating < 1 OR @rating > 5
    BEGIN
        THROW 50008, 'Rating has to be 1 - 5.', 1;
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM purchased_membership 
        WHERE client_id = @client_id 
        AND valid_until >= GETDATE() 
        AND status = 'active'
    )
    BEGIN
        THROW 50006, 'Client has no active membership.', 1;
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 
        FROM class_booking cb
        JOIN schedule s ON cb.schedule_id = s.schedule_id
        WHERE cb.client_id = @client_id
          AND s.trainer_id = @trainer_id
    )
    BEGIN
        THROW 50007, 'Client did not attend any classes with this trainer.', 1;
        RETURN;
    END

    INSERT INTO feedback (client_id, trainer_id, rating, comment, feedback_date)
    VALUES (@client_id, @trainer_id, @rating, @comment, GETDATE());

    PRINT 'Review added successfully';
END;