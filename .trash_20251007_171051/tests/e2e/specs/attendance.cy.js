describe('LabFace Attendance System', () => {
  beforeEach(() => {
    // Login as professor
    cy.visit('/professor/login');
    cy.get('input[type="email"]').type('john.doe@university.edu');
    cy.get('input[type="password"]').type('password123');
    cy.get('button[type="submit"]').click();
    cy.url().should('include', '/professor/dashboard');
  });

  describe('Class Management', () => {
    it('should create a new class', () => {
      cy.visit('/professor/classes/new');
      
      cy.get('input[name="semester"]').type('Fall 2024');
      cy.get('input[name="school_year"]').type('2024-2025');
      cy.get('input[name="subject"]').type('Computer Science 101');
      cy.get('input[name="section"]').type('A');
      cy.get('button[type="submit"]').click();
      
      cy.url().should('include', '/professor/classes');
      cy.get('.success').should('contain', 'Class created successfully');
    });

    it('should display class list', () => {
      cy.visit('/professor/classes');
      cy.get('.class-card').should('be.visible');
      cy.get('.class-card').should('contain', 'Computer Science 101');
    });

    it('should start an attendance session', () => {
      cy.visit('/professor/classes');
      cy.get('.class-card').first().within(() => {
        cy.get('button').contains('Start Session').click();
      });
      
      cy.url().should('include', '/professor/session/');
      cy.get('h1').should('contain', 'Live Attendance');
    });
  });

  describe('Live Attendance Session', () => {
    beforeEach(() => {
      // Start a session
      cy.visit('/professor/classes');
      cy.get('.class-card').first().within(() => {
        cy.get('button').contains('Start Session').click();
      });
    });

    it('should display live attendance interface', () => {
      cy.get('h1').should('contain', 'Live Attendance');
      cy.get('.attendance-stats').should('be.visible');
      cy.get('.camera-feed').should('be.visible');
      cy.get('.attendance-log').should('be.visible');
    });

    it('should show attendance statistics', () => {
      cy.get('.stat-card').should('contain', 'Present');
      cy.get('.stat-card').should('contain', 'Absent');
      cy.get('.stat-card').should('contain', 'Late');
      cy.get('.stat-card').should('contain', 'Total');
    });

    it('should display camera feed', () => {
      cy.get('.camera-feed').should('be.visible');
      cy.get('.camera-feed img').should('have.attr', 'src');
    });

    it('should show real-time attendance log', () => {
      cy.get('.attendance-log').should('be.visible');
      cy.get('.attendance-log .log-entry').should('exist');
    });

    it('should handle manual attendance adjustments', () => {
      cy.get('button').contains('Manual Adjust').click();
      cy.get('.modal').should('be.visible');
      
      cy.get('select[name="student"]').select('Jane Smith');
      cy.get('select[name="status"]').select('Present');
      cy.get('button[type="submit"]').click();
      
      cy.get('.modal').should('not.be.visible');
      cy.get('.success').should('contain', 'Attendance updated');
    });

    it('should export attendance data', () => {
      cy.get('button').contains('Export CSV').click();
      
      // Check if download started
      cy.window().then((win) => {
        cy.stub(win, 'open').as('windowOpen');
      });
    });

    it('should stop the session', () => {
      cy.get('button').contains('Stop Session').click();
      cy.get('.modal').should('be.visible');
      cy.get('button').contains('Confirm').click();
      
      cy.url().should('include', '/professor/classes');
      cy.get('.success').should('contain', 'Session stopped');
    });
  });

  describe('Student Check-in', () => {
    beforeEach(() => {
      // Login as student
      cy.visit('/student/login');
      cy.get('input[type="email"]').type('jane.smith@student.edu');
      cy.get('input[type="password"]').type('password123');
      cy.get('button[type="submit"]').click();
      cy.url().should('include', '/student/dashboard');
    });

    it('should display check-in interface', () => {
      cy.visit('/student/checkin');
      cy.get('h1').should('contain', 'Check In');
      cy.get('.camera-preview').should('be.visible');
      cy.get('button').contains('Capture Photo').should('be.visible');
    });

    it('should capture and submit photo', () => {
      cy.visit('/student/checkin');
      
      // Mock camera capture
      cy.get('button').contains('Capture Photo').click();
      cy.get('.photo-preview').should('be.visible');
      
      cy.get('button').contains('Submit Check-in').click();
      cy.get('.success').should('contain', 'Check-in successful');
    });

    it('should show attendance history', () => {
      cy.visit('/student/dashboard');
      cy.get('.attendance-history').should('be.visible');
      cy.get('.attendance-history .history-item').should('exist');
    });

    it('should display next class information', () => {
      cy.visit('/student/dashboard');
      cy.get('.next-class-card').should('be.visible');
      cy.get('.next-class-card').should('contain', 'Computer Science 101');
    });
  });

  describe('Real-time Updates', () => {
    it('should receive real-time attendance updates', () => {
      // Mock WebSocket connection
      cy.window().then((win) => {
        cy.stub(win, 'WebSocket').as('WebSocket');
      });
      
      cy.visit('/professor/session/1');
      
      // Simulate WebSocket message
      cy.get('@WebSocket').then((stub) => {
        stub.trigger('message', {
          data: JSON.stringify({
            type: 'attendance_update',
            student_id: 'STU001',
            status: 'present',
            timestamp: new Date().toISOString()
          })
        });
      });
      
      cy.get('.attendance-log .log-entry').should('contain', 'STU001');
    });

    it('should update attendance statistics in real-time', () => {
      cy.visit('/professor/session/1');
      
      // Check initial stats
      cy.get('.stat-card').contains('Present').should('contain', '0');
      
      // Simulate attendance update
      cy.window().then((win) => {
        const event = new CustomEvent('attendance_update', {
          detail: {
            student_id: 'STU001',
            status: 'present'
          }
        });
        win.dispatchEvent(event);
      });
      
      cy.get('.stat-card').contains('Present').should('contain', '1');
    });
  });

  describe('Error Handling', () => {
    it('should handle camera errors', () => {
      cy.visit('/student/checkin');
      
      // Mock camera error
      cy.window().then((win) => {
        cy.stub(win.navigator.mediaDevices, 'getUserMedia').rejects(new Error('Camera not available'));
      });
      
      cy.get('button').contains('Capture Photo').click();
      cy.get('.error').should('contain', 'Camera not available');
    });

    it('should handle network errors', () => {
      cy.visit('/professor/session/1');
      
      // Mock network error
      cy.intercept('GET', '/api/presence_events*', {
        statusCode: 500,
        body: { error: 'Network error' }
      }).as('networkError');
      
      cy.get('.attendance-log').should('be.visible');
      cy.get('.error').should('contain', 'Network error');
    });

    it('should handle face recognition errors', () => {
      cy.visit('/student/checkin');
      
      // Mock face recognition error
      cy.intercept('POST', '/api/attendance/checkin', {
        statusCode: 400,
        body: { error: 'No face detected' }
      }).as('faceError');
      
      cy.get('button').contains('Capture Photo').click();
      cy.get('button').contains('Submit Check-in').click();
      cy.get('.error').should('contain', 'No face detected');
    });
  });

  describe('Responsive Design', () => {
    it('should work on mobile devices', () => {
      cy.viewport(375, 667);
      cy.visit('/professor/session/1');
      
      cy.get('.attendance-stats').should('be.visible');
      cy.get('.camera-feed').should('be.visible');
      cy.get('.attendance-log').should('be.visible');
    });

    it('should work on tablet devices', () => {
      cy.viewport(768, 1024);
      cy.visit('/professor/session/1');
      
      cy.get('.attendance-stats').should('be.visible');
      cy.get('.camera-feed').should('be.visible');
      cy.get('.attendance-log').should('be.visible');
    });
  });

  describe('Accessibility', () => {
    it('should be accessible with keyboard navigation', () => {
      cy.visit('/professor/session/1');
      
      // Tab through interactive elements
      cy.get('body').tab();
      cy.focused().should('be.visible');
      
      // Check for proper focus indicators
      cy.get('button').first().focus();
      cy.get('button').first().should('have.focus');
    });

    it('should have proper ARIA labels', () => {
      cy.visit('/professor/session/1');
      
      cy.get('[aria-label]').should('exist');
      cy.get('[role="button"]').should('exist');
      cy.get('[role="status"]').should('exist');
    });
  });
});
