// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

// Custom commands for LabFace testing

Cypress.Commands.add('loginAsProfessor', (email = 'john.doe@university.edu', password = 'password123') => {
  cy.visit('/professor/login');
  cy.get('input[type="email"]').type(email);
  cy.get('input[type="password"]').type(password);
  cy.get('button[type="submit"]').click();
  cy.url().should('include', '/professor/dashboard');
});

Cypress.Commands.add('loginAsStudent', (email = 'jane.smith@student.edu', password = 'password123') => {
  cy.visit('/student/login');
  cy.get('input[type="email"]').type(email);
  cy.get('input[type="password"]').type(password);
  cy.get('button[type="submit"]').click();
  cy.url().should('include', '/student/dashboard');
});

Cypress.Commands.add('createClass', (classData = {}) => {
  const defaultClass = {
    semester: 'Fall 2024',
    school_year: '2024-2025',
    subject: 'Computer Science 101',
    section: 'A'
  };
  
  const classInfo = { ...defaultClass, ...classData };
  
  cy.visit('/professor/classes/new');
  cy.get('input[name="semester"]').type(classInfo.semester);
  cy.get('input[name="school_year"]').type(classInfo.school_year);
  cy.get('input[name="subject"]').type(classInfo.subject);
  cy.get('input[name="section"]').type(classInfo.section);
  cy.get('button[type="submit"]').click();
  
  cy.url().should('include', '/professor/classes');
  cy.get('.success').should('contain', 'Class created successfully');
});

Cypress.Commands.add('startSession', () => {
  cy.visit('/professor/classes');
  cy.get('.class-card').first().within(() => {
    cy.get('button').contains('Start Session').click();
  });
  cy.url().should('include', '/professor/session/');
});

Cypress.Commands.add('stopSession', () => {
  cy.get('button').contains('Stop Session').click();
  cy.get('.modal').should('be.visible');
  cy.get('button').contains('Confirm').click();
  cy.url().should('include', '/professor/classes');
});

Cypress.Commands.add('checkInStudent', () => {
  cy.visit('/student/checkin');
  cy.get('button').contains('Capture Photo').click();
  cy.get('.photo-preview').should('be.visible');
  cy.get('button').contains('Submit Check-in').click();
  cy.get('.success').should('contain', 'Check-in successful');
});

Cypress.Commands.add('mockWebSocket', () => {
  cy.window().then((win) => {
    const mockWebSocket = {
      readyState: 1,
      send: cy.stub(),
      close: cy.stub(),
      addEventListener: cy.stub(),
      removeEventListener: cy.stub(),
      dispatchEvent: cy.stub()
    };
    
    cy.stub(win, 'WebSocket').returns(mockWebSocket);
  });
});

Cypress.Commands.add('simulateAttendanceUpdate', (studentId, status) => {
  cy.window().then((win) => {
    const event = new CustomEvent('attendance_update', {
      detail: {
        student_id: studentId,
        status: status,
        timestamp: new Date().toISOString()
      }
    });
    win.dispatchEvent(event);
  });
});

Cypress.Commands.add('mockCamera', () => {
  cy.window().then((win) => {
    const mockMediaDevices = {
      getUserMedia: cy.stub().resolves({
        getTracks: () => [{
          stop: cy.stub()
        }]
      })
    };
    
    cy.stub(win.navigator, 'mediaDevices').value(mockMediaDevices);
  });
});

Cypress.Commands.add('mockFaceRecognition', (success = true) => {
  if (success) {
    cy.intercept('POST', '/api/attendance/checkin', {
      statusCode: 200,
      body: {
        success: true,
        message: 'Check-in successful'
      }
    }).as('checkinSuccess');
  } else {
    cy.intercept('POST', '/api/attendance/checkin', {
      statusCode: 400,
      body: {
        error: 'No face detected'
      }
    }).as('checkinError');
  }
});

Cypress.Commands.add('waitForServices', () => {
  // Wait for backend
  cy.request('GET', 'http://localhost:4000/api/health').then((response) => {
    expect(response.status).to.eq(200);
  });
  
  // Wait for ML service
  cy.request('GET', 'http://localhost:8000/health').then((response) => {
    expect(response.status).to.eq(200);
  });
  
  // Wait for frontend
  cy.visit('/');
  cy.get('body').should('be.visible');
});

Cypress.Commands.add('clearDatabase', () => {
  // Clear test data
  cy.request('POST', 'http://localhost:4000/api/test/clear');
});

Cypress.Commands.add('seedTestData', () => {
  // Seed test data
  cy.request('POST', 'http://localhost:4000/api/test/seed');
});

Cypress.Commands.add('takeScreenshot', (name) => {
  cy.screenshot(name, {
    capture: 'fullPage',
    overwrite: true
  });
});

Cypress.Commands.add('checkAccessibility', () => {
  // Check for common accessibility issues
  cy.get('img').each(($img) => {
    cy.wrap($img).should('have.attr', 'alt');
  });
  
  cy.get('button').each(($button) => {
    cy.wrap($button).should('have.attr', 'aria-label');
  });
  
  cy.get('form').each(($form) => {
    cy.wrap($form).should('have.attr', 'role');
  });
});

Cypress.Commands.add('checkPerformance', () => {
  // Check page load performance
  cy.window().then((win) => {
    const performance = win.performance;
    const navigation = performance.getEntriesByType('navigation')[0];
    
    expect(navigation.loadEventEnd - navigation.loadEventStart).to.be.lessThan(3000);
  });
});

Cypress.Commands.add('checkSecurity', () => {
  // Check for security headers
  cy.request('GET', 'http://localhost:3000').then((response) => {
    expect(response.headers).to.have.property('x-frame-options');
    expect(response.headers).to.have.property('x-content-type-options');
    expect(response.headers).to.have.property('x-xss-protection');
  });
});

// Custom command for testing WebSocket connections
Cypress.Commands.add('testWebSocket', (url, expectedMessages) => {
  cy.window().then((win) => {
    const ws = new win.WebSocket(url);
    const messages = [];
    
    ws.onmessage = (event) => {
      messages.push(JSON.parse(event.data));
    };
    
    cy.wait(1000).then(() => {
      expect(messages).to.have.length(expectedMessages.length);
      expectedMessages.forEach((expected, index) => {
        expect(messages[index]).to.deep.include(expected);
      });
    });
  });
});

// Custom command for testing file uploads
Cypress.Commands.add('uploadFile', (selector, filePath) => {
  cy.get(selector).selectFile(filePath);
});

// Custom command for testing drag and drop
Cypress.Commands.add('dragAndDrop', (sourceSelector, targetSelector) => {
  cy.get(sourceSelector).trigger('dragstart');
  cy.get(targetSelector).trigger('drop');
});

// Custom command for testing keyboard shortcuts
Cypress.Commands.add('pressKey', (key) => {
  cy.get('body').type(key);
});

// Custom command for testing mobile gestures
Cypress.Commands.add('swipe', (selector, direction) => {
  cy.get(selector).trigger('touchstart', { touches: [{ clientX: 0, clientY: 0 }] });
  cy.get(selector).trigger('touchmove', { touches: [{ clientX: direction === 'left' ? -100 : 100, clientY: 0 }] });
  cy.get(selector).trigger('touchend');
});

// Custom command for testing print functionality
Cypress.Commands.add('testPrint', () => {
  cy.window().then((win) => {
    cy.stub(win, 'print').as('printStub');
  });
  
  cy.get('button').contains('Print').click();
  cy.get('@printStub').should('have.been.called');
});

// Custom command for testing download functionality
Cypress.Commands.add('testDownload', (selector) => {
  cy.get(selector).click();
  
  // Check if download started
  cy.window().then((win) => {
    cy.stub(win, 'open').as('windowOpen');
  });
});

// Custom command for testing clipboard functionality
Cypress.Commands.add('testClipboard', (selector) => {
  cy.get(selector).click();
  
  cy.window().then((win) => {
    cy.stub(win.navigator.clipboard, 'writeText').as('clipboardWrite');
  });
});

// Custom command for testing geolocation
Cypress.Commands.add('mockGeolocation', (lat, lng) => {
  cy.window().then((win) => {
    cy.stub(win.navigator.geolocation, 'getCurrentPosition').callsFake((callback) => {
      callback({
        coords: {
          latitude: lat,
          longitude: lng
        }
      });
    });
  });
});

// Custom command for testing notifications
Cypress.Commands.add('testNotifications', () => {
  cy.window().then((win) => {
    cy.stub(win.Notification, 'requestPermission').resolves('granted');
    cy.stub(win, 'Notification').as('NotificationStub');
  });
});

// Custom command for testing service workers
Cypress.Commands.add('testServiceWorker', () => {
  cy.window().then((win) => {
    cy.stub(win.navigator.serviceWorker, 'register').as('swRegister');
  });
});

// Custom command for testing push notifications
Cypress.Commands.add('testPushNotifications', () => {
  cy.window().then((win) => {
    cy.stub(win.PushManager, 'subscribe').as('pushSubscribe');
  });
});

// Custom command for testing offline functionality
Cypress.Commands.add('testOffline', () => {
  cy.window().then((win) => {
    cy.stub(win.navigator, 'onLine').value(false);
    cy.get('body').trigger('offline');
  });
});

// Custom command for testing online functionality
Cypress.Commands.add('testOnline', () => {
  cy.window().then((win) => {
    cy.stub(win.navigator, 'onLine').value(true);
    cy.get('body').trigger('online');
  });
});
