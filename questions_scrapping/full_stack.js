module.exports = [
  {
    question: "Which HTML5 tag is used to specify the main content of a document?",
    options: ["<main>", "<content>", "<section>", "<body>"],
    answer: "<main>",
    explanation: "The <main> tag specifies the main content of a document. The content inside the <main> element should be unique to the document."
  },
  {
    question: "In the CSS Box Model, which property is the innermost component?",
    options: ["Margin", "Border", "Padding", "Content"],
    answer: "Content",
    explanation: "The CSS Box Model consists of: Content (innermost), Padding, Border, and Margin (outermost)."
  },
  {
    question: "Which CSS property controls the stacking order of elements?",
    options: ["z-index", "stack-order", "position", "float"],
    answer: "z-index",
    explanation: "The z-index property specifies the stack order of an element. An element with greater stack order is always in front of an element with a lower stack order."
  },
  {
    question: "Which of the following is NOT a valid value for the 'display' property?",
    options: ["block", "inline-block", "flex", "hidden"],
    answer: "hidden",
    explanation: "'hidden' is not a value for 'display'. To hide an element, you can use 'display: none' or 'visibility: hidden'."
  },
  {
    question: "What is the difference between 'visibility: hidden' and 'display: none'?",
    options: ["No difference", "'visibility: hidden' removes the element from the layout, 'display: none' hides it but keeps space", "'display: none' removes the element from the layout, 'visibility: hidden' hides it but keeps space", "'display: none' is for block elements only"],
    answer: "'display: none' removes the element from the layout, 'visibility: hidden' hides it but keeps space",
    explanation: "'display: none' removes the element completely from the document flow. 'visibility: hidden' makes it invisible but it still takes up space."
  },
  {
    question: "What is the output of 'typeof null' in JavaScript?",
    options: ["'null'", "'undefined'", "'object'", "'number'"],
    answer: "'object'",
    explanation: "This is a long-standing bug in JavaScript, but 'typeof null' returns 'object'."
  },
  {
    question: "Which keyword is used to declare a block-scoped variable in JavaScript?",
    options: ["var", "let", "global", "def"],
    answer: "let",
    explanation: "'let' and 'const' declare block-scoped variables. 'var' declares a function-scoped or globally-scoped variable."
  },
  {
    question: "What does '===' operator check?",
    options: ["Value only", "Type only", "Value and Type", "Reference only"],
    answer: "Value and Type",
    explanation: "The '===' operator (strict equality) checks both the value and the data type of the operands."
  },
  {
    question: "What is a Closure in JavaScript?",
    options: ["A function that has access to its outer function scope even after the outer function has returned", "A function typically used to close the window", "A method to secure code directly", "A way to close a database connection"],
    answer: "A function that has access to its outer function scope even after the outer function has returned",
    explanation: "A closure is the combination of a function bundled together (enclosed) with references to its surrounding state (the lexical environment)."
  },
  {
    question: "What is the result of 2 + '2' in JavaScript?",
    options: ["4", "'22'", "NaN", "Error"],
    answer: "'22'",
    explanation: "JavaScript performs type coercion. When adding a number and a string, the number is converted to a string and concatenated."
  },
  {
    question: "Which array method creates a new array with the results of calling a provided function on every element?",
    options: ["forEach()", "map()", "filter()", "reduce()"],
    answer: "map()",
    explanation: "The map() method creates a new array populated with the results of calling a provided function on every element in the calling array."
  },
  {
    question: "What concept in React allows you to synchronize a component with an external system?",
    options: ["State", "Props", "Effects (useEffect)", "Context"],
    answer: "Effects (useEffect)",
    explanation: "The useEffect Hook allows you to perform side effects in function components, such as data fetching, subscriptions, or manually changing the DOM."
  },
  {
    question: "What is the Virtual DOM?",
    options: ["A direct copy of the real DOM", "A lightweight copy of the DOM kept in memory", "A browser plugin", "A database for DOM elements"],
    answer: "A lightweight copy of the DOM kept in memory",
    explanation: "The Virtual DOM is a programming concept where a virtual representation of a UI is kept in memory and synced with the 'real' DOM by a library such as ReactDOM."
  },
  {
    question: "In Redux, what is the only way to change the state?",
    options: ["Directly modifying the state object", "Emitting an action", "Using setState", "Through a classic callback"],
    answer: "Emitting an action",
    explanation: "In Redux, the state is read-only. The only way to change the state is to emit an action, an object describing what happened."
  },
  {
    question: "Which Node.js module is used to create a web server?",
    options: ["fs", "path", "http", "os"],
    answer: "http",
    explanation: "The 'http' module allows Node.js to transfer data over the Hyper Text Transfer Protocol (HTTP) and is used to create a server."
  },
  {
    question: "What is 'middleware' in Express.js?",
    options: ["A database driver", "Functions that have access to the request, response, and next function", "A front-end framework", "A security protocol"],
    answer: "Functions that have access to the request, response, and next function",
    explanation: "Middleware functions are functions that have access to the request object (req), the response object (res), and the next middleware function in the application’s request-response cycle."
  },
  {
    question: "Which of the following is a non-relational (NoSQL) database?",
    options: ["PostgreSQL", "MySQL", "MongoDB", "SQLite"],
    answer: "MongoDB",
    explanation: "MongoDB is a document-oriented NoSQL database, unlike PostgreSQL, MySQL, and SQLite which are relational (SQL) databases."
  },
  {
    question: "In SQL, which clause is used to filter records?",
    options: ["SELECT", "WHERE", "GROUP BY", "ORDER BY"],
    answer: "WHERE",
    explanation: "The WHERE clause is used to filter records. It is used to extract only those records that fulfill a specified condition."
  },
  {
    question: "What does ACID stand for in databases?",
    options: ["Atomicity, Consistency, Isolation, Durability", "Association, Class, Interface, Data", "Auto, Constant, Immediate, Direct", "Access, Control, Input, Delete"],
    answer: "Atomicity, Consistency, Isolation, Durability",
    explanation: "ACID is a set of properties of database transactions intended to guarantee data validity despite errors, power failures, and other mishaps."
  },
  {
    question: "What is the default HTTP method for a browser API call?",
    options: ["POST", "GET", "PUT", "DELETE"],
    answer: "GET",
    explanation: "When you enter a URL in the address bar or click a link, the browser performs a GET request by default."
  },
  {
    question: "Which HTTP status code indicates a successful request?",
    options: ["200", "301", "404", "500"],
    answer: "200",
    explanation: "Status code 200 (OK) indicates that the request has succeeded."
  },
  {
    question: "What is the main difference between PUT and PATCH?",
    options: ["PUT creates, PATCH deletes", "PUT updates the entire resource, PATCH updates partial fields", "PUT is secure, PATCH is not", "Only PATCH is idempotent"],
    answer: "PUT updates the entire resource, PATCH updates partial fields",
    explanation: "PUT is used to replace an entire resource. PATCH is used to apply partial modifications to a resource."
  },
  {
    question: "What problem does GraphQL solve that REST often struggles with?",
    options: ["Security", "Over-fetching and Under-fetching", "Database connectivity", "Server speed"],
    answer: "Over-fetching and Under-fetching",
    explanation: "GraphQL allows clients to request exactly the data they need, solving REST's common issues of getting too much data (over-fetching) or not enough (under-fetching)."
  },
  {
    question: "Which Git command is used to record changes to the repository?",
    options: ["git add", "git commit", "git push", "git status"],
    answer: "git commit",
    explanation: "git commit records changes to the repository. 'git add' stages changes, and 'git push' uploads them to a remote repo."
  },
  {
    question: "What is a 'merge conflict' in Git?",
    options: ["When the server is down", "When two branches have changed the same part of a file differently", "When a file is too large", "When credentials are wrong"],
    answer: "When two branches have changed the same part of a file differently",
    explanation: "A merge conflict occurs when Git is unable to automatically resolve differences in code between two commits."
  },
  {
    question: "What is the main purpose of Docker?",
    options: ["To compile code faster", "To containerize applications ensuring consistency across environments", "To replace Virtual Machines completely", "To manage databases"],
    answer: "To containerize applications ensuring consistency across environments",
    explanation: "Docker allows developers to package applications into containers that include everything needed to run (libraries, code, runtime), ensuring it runs the same everywhere."
  },
  {
    question: "What file is used to define a multi-container Docker application?",
    options: ["Dockerfile", "docker-compose.yml", "package.json", "config.xml"],
    answer: "docker-compose.yml",
    explanation: "docker-compose.yml is a YAML file used to define services, networks, and volumes for a multi-container Docker application."
  },
  {
    question: "What does CI/CD stand for?",
    options: ["Continuous Integration / Continuous Deployment", "Code Inspection / Code Delivery", "Cloud Integration / Cloud Distribution", "Computer Interface / Computer Design"],
    answer: "Continuous Integration / Continuous Deployment",
    explanation: "CI/CD stands for Continuous Integration and Continuous Delivery/Deployment, a method to frequently deliver apps to customers by introducing automation."
  },
  {
    question: "Which of the following is a security vulnerability where a script is injected into a trusted website?",
    options: ["SQL Injection", "CSRF", "XSS", "DDoS"],
    answer: "XSS",
    explanation: "Cross-Site Scripting (XSS) is a vulnerability that allows attackers to inject malicious scripts into web pages viewed by other users."
  },
  {
    question: "What is the purpose of CORS?",
    options: ["To speed up requests", "To allow servers to specify who can access their assets", "To compress data", "To encrypt passwords"],
    answer: "To allow servers to specify who can access their assets",
    explanation: "Cross-Origin Resource Sharing (CORS) is a mechanism that uses HTTP headers to tell browsers to give a web application running at one origin, access to selected resources from a different origin."
  },
  {
    question: "What storage mechanism persists data even after the browser window is closed?",
    options: ["SessionStorage", "LocalStorage", "Cookies (Session)", "RAM"],
    answer: "LocalStorage",
    explanation: "LocalStorage allows you to save key/value pairs in a web browser. It stores data with no expiration date."
  },
  {
    question: "In the context of APIs, what is a JWT?",
    options: ["Java Web Token", "JSON Web Token", "JavaScript Web Token", "Joint Web Transfer"],
    answer: "JSON Web Token",
    explanation: "JSON Web Token (JWT) is an open standard that defines a compact and self-contained way for securely transmitting information between parties as a JSON object."
  },
  {
    question: "Which HTTP status code represents 'Forbidden'?",
    options: ["400", "401", "403", "404"],
    answer: "403",
    explanation: "403 Forbidden means the server understood the request but refuses to authorize it. 401 is Unauthorized (authentication validation failed)."
  },
  {
    question: "What is the purpose of 'npm'?",
    options: ["Node Package Manager", "New Project Maker", "Node Process Monitor", "Network Protocol Manager"],
    answer: "Node Package Manager",
    explanation: "npm (Node Package Manager) is the default package manager for the JavaScript runtime environment Node.js."
  },
  {
    question: "Can an arrow function be used as a constructor?",
    options: ["Yes", "No", "Only in strict mode", "Only if it has no arguments"],
    answer: "No",
    explanation: "Arrow functions do not have their own 'this' binding and cannot be used as constructors (you cannot use 'new' with them)."
  },
  {
    question: "What is 'hoisting' in JavaScript?",
    options: ["Moving declarations to the top of the scope", "Lifting a variable to the global scope", "Optimizing code execution", "Deleting unused variables"],
    answer: "Moving declarations to the top of the scope",
    explanation: "Hoisting is JavaScript's default behavior of moving declarations to the top of the current scope."
  },
  {
    question: "Which CSS unit is relative to the font-size of the root element (html)?",
    options: ["em", "rem", "px", "%"],
    answer: "rem",
    explanation: "'rem' stands for 'root em'. It is relative to the font-size of the root element (<html>)."
  },
  {
    question: "What is an 'event loop' responsible for?",
    options: ["Handling synchronous code only", "Managing the call stack and callback queue interaction", "Drawing the UI", "Connecting to the database"],
    answer: "Managing the call stack and callback queue interaction",
    explanation: "The event loop monitors the Call Stack and the Callback Queue. If the Call Stack is empty, it will take the first event from the queue and push it to the Call Stack."
  },
  {
    question: "What is a 'foreign key' in a database?",
    options: ["A key used to encrypt data", "A field that uniquely identifies a record in another table", "A password for the database", "A primary key in the same table"],
    answer: "A field that uniquely identifies a record in another table",
    explanation: "A foreign key is a field (or collection of fields) in one table, that refers to the PRIMARY KEY in another table."
  },
  {
    question: "Which command would you use to install dependencies defined in package.json?",
    options: ["npm start", "npm init", "npm install", "npm build"],
    answer: "npm install",
    explanation: "npm install (or npm i) installs the dependencies listed in the package.json file."
  },
  {
    question: "What does the 'defer' attribute do in a <script> tag?",
    options: ["Loads the script immediately and pauses parsing", "Downloads the script while parsing, executes after HTML parsing is complete", "Ignores the script", "Executes the script before anything else"],
    answer: "Downloads the script while parsing, executes after HTML parsing is complete",
    explanation: "Scripts with 'defer' are downloaded in parallel to parsing the page, and executed after the page has finished parsing."
  },
  {
    question: "Which protocol is stateless?",
    options: ["HTTP", "FTP", "TCP", "WebSocket"],
    answer: "HTTP",
    explanation: "HTTP is a stateless protocol, meaning the server does not keep any data (state) between two requests."
  },
  {
    question: "What is the primary function of a reverse proxy?",
    options: ["To hack the server", "To forward client requests to appropriate backend servers", "To delete logs", "To store user passwords"],
    answer: "To forward client requests to appropriate backend servers",
    explanation: "A reverse proxy sits in front of one or more web servers and intercepts requests from clients, forwarding them to the appropriate web server."
  },
  {
    question: "What is 'Server-Side Rendering' (SSR)?",
    options: ["Rendering HTML on the client browser", "Generating the full HTML for a page on the server before sending it to the client", "Using only static HTML files", "Rendering graphics on the GPU"],
    answer: "Generating the full HTML for a page on the server before sending it to the client",
    explanation: "SSR involves rendering the component on the server and sending the HTMl string to the client, which is good for SEO and initial load performance."
  },
  {
    question: "In Python (often used in backend), what is the equivalent of a Dictionary in JavaScript?",
    options: ["Array", "Object", "List", "Set"],
    answer: "Object",
    explanation: "A Python Dictionary (key-value pairs) is conceptually very similar to a JavaScript Object."
  },
  {
    question: "What is the purpose of 'sql injection'?",
    options: ["To optimize SQL queries", "To insert malicious SQL code to manipulate the database", "To backup the database", "To format SQL code"],
    answer: "To insert malicious SQL code to manipulate the database",
    explanation: "SQL Injection is a code injection technique used to attack data-driven applications by inserting malicious SQL statements into entry fields for execution."
  },
  {
    question: "Which command builds a Docker image from a Dockerfile?",
    options: ["docker run", "docker build", "docker pull", "docker create"],
    answer: "docker build",
    explanation: "The 'docker build' command builds Docker images from a Dockerfile and a 'context'."
  },
  {
    question: "What is 'semantic versioning' (SemVer)?",
    options: ["Version naming based on dates", "A versioning system using Major.Minor.Patch", "Random version numbers", "Alphabetical versioning"],
    answer: "A versioning system using Major.Minor.Patch",
    explanation: "Semantic Versioning uses the format MAJOR.MINOR.PATCH (e.g., 1.0.0), conveying meaning about the underlying changes."
  },
  {
    question: "What does content negotiation in HTTP involve?",
    options: ["Negotiating the price of content", "Determining the best media type for the response (e.g., JSON vs XML)", "Blocking content", "Filtering bad words"],
    answer: "Determining the best media type for the response (e.g., JSON vs XML)",
    explanation: "Content negotiation is the mechanism that is used for serving different representations of a resource at the same URI, dealing with headers like Accept."
  },
  {
    question: "Which of the following serves as the entry point for a React application's rendering?",
    options: ["ReactDOM.render()", "React.start()", "document.render()", "App.init()"],
    answer: "ReactDOM.render()",
    explanation: "ReactDOM.render() (or createRoot in React 18) interacts with the DOM to render React components into a root element."
  },
  {
    question: "What is the primary purpose of the 'z-index' property in CSS?",
    options: ["To control the transparency of an element", "To control the vertical stacking order of elements", "To scale an element along the z-axis", "To adjust the zoom level"],
    answer: "To control the vertical stacking order of elements",
    explanation: "z-index determines the stack level of an element; elements with higher z-index overlap those with lower z-index."
  },
  {
    question: "In JavaScript, what is the output of '1' + 1?",
    options: ["2", "'11'", "undefined", "NaN"],
    answer: "'11'",
    explanation: "JavaScript performs type coercion, treating the number as a string and concatenating them."
  },
  {
    question: "Which hook would you use to perform side effects in a functional React component?",
    options: ["useState", "useEffect", "useReducer", "useContext"],
    answer: "useEffect",
    explanation: "useEffect is specifically designed to handle side effects like data fetching, subscriptions, or DOM manipulation."
  },
  {
    question: "What does semantic HTML improve?",
    options: ["Execution speed of scripts", "Design aesthetics", "Accessibility and SEO", "Database connectivity"],
    answer: "Accessibility and SEO",
    explanation: "Semantic tags (header, article, footer) provide meaning to screen readers and search engines."
  },
  {
    question: "What is the difference between specificities of an ID and a Class selector in CSS?",
    options: ["ID has higher specificity", "Class has higher specificity", "They are equal", "It depends on the order"],
    answer: "ID has higher specificity",
    explanation: "An ID selector is more specific than a class selector, meaning styles defined by ID will override class styles."
  },
  {
    question: "Which method prevents the default behavior of a form submission in JavaScript?",
    options: ["event.stopPropagation()", "event.halt()", "event.preventDefault()", "return false"],
    answer: "event.preventDefault()",
    explanation: "event.preventDefault() stops the browser's default action, such as reloading the page on form submit."
  },
  {
    question: "What concept allows JavaScript to access variables from an outer function scope even after it has returned?",
    options: ["Hoisting", "Recursion", "Closure", "Currying"],
    answer: "Closure",
    explanation: "A closure gives you access to an outer function's scope from an inner function, even after the outer function finishes."
  },
  {
    question: "What is the virtual DOM in React?",
    options: ["A direct copy of the browser DOM", "A lightweight metadata representation of the real DOM", "A browser plugin", "A backend service"],
    answer: "A lightweight metadata representation of the real DOM",
    explanation: "React uses a virtual DOM to optimize updates by comparing changes (diffing) before interacting with the slow real DOM."
  },
  {
    question: "Which Redux principle dictates that state is read-only?",
    options: ["Single source of truth", "State is read-only", "Changes are made with pure functions", "View is a function of state"],
    answer: "State is read-only",
    explanation: "The only way to change the state is to emit an action, an object describing what happened."
  },
  {
    question: "In Node.js, which API is used for non-blocking I/O operations?",
    options: ["Threads", "libuv", "Apache", "Nginx"],
    answer: "libuv",
    explanation: "Node.js uses libuv to handle asynchronous I/O operations via the event loop."
  },
  {
    question: "What is middleware in Express.js?",
    options: ["A hardware component", "Functions that access req, res, and next objects", "The database layer", "Frontend routing logic"],
    answer: "Functions that access req, res, and next objects",
    explanation: "Middleware functions can execute code, modify request/response objects, and end the request-response cycle."
  },
  {
    question: "Which HTTP method is idempotent and used to update a resource entirely?",
    options: ["POST", "PUT", "PATCH", "DELETE"],
    answer: "PUT",
    explanation: "PUT replaces the resource. Repeated requests produce the same result (idempotent)."
  },
  {
    question: "What is the purpose of JWT (JSON Web Token)?",
    options: ["To encrypt database passwords", "To securely transmit information between parties as a JSON object", "To format JSON responses", "To managing file uploads"],
    answer: "To securely transmit information between parties as a JSON object",
    explanation: "JWTs are commonly used for authorization and information exchange."
  },
  {
    question: "In a RESTful API, which status code indicates 'Not Found'?",
    options: ["200", "500", "404", "401"],
    answer: "404",
    explanation: "404 Not Found is the standard HTTP response code for when a requested resource could not be found."
  },
  {
    question: "Which feature allows Node.js to use an event-driven architecture?",
    options: ["Multi-threading", "The Event Loop", "Synchronous execution", "Blocking I/O"],
    answer: "The Event Loop",
    explanation: "The Event Loop handles asynchronous callbacks, allowing Node.js to perform non-blocking I/O."
  },
  {
    question: "What constitutes a 'Microservice' architecture?",
    options: ["One large codebase", "A collection of loosely coupled services", "Using only micro-controllers", "Client-side rendering"],
    answer: "A collection of loosely coupled services",
    explanation: "Microservices structure an application as a collection of smaller, independent services."
  },
  {
    question: "Which Node.js module is used to create a web server?",
    options: ["fs", "path", "http", "os"],
    answer: "http",
    explanation: "The 'http' module allows Node.js to transfer data over the Hyper Text Transfer Protocol (HTTP)."
  },
  {
    question: "What does GraphQL solve that REST might struggle with?",
    options: ["Over-fetching and under-fetching of data", "Database indexing", "Server downtime", "Authentication"],
    answer: "Over-fetching and under-fetching of data",
    explanation: "GraphQL allows clients to request exactly the data they need, nothing more, nothing less."
  },
  {
    question: "What is simple definition of a WebSocket?",
    options: ["A secure HTTP request", "A persistent, two-way communication channel", "A database connector", "A CSS framework"],
    answer: "A persistent, two-way communication channel",
    explanation: "WebSockets provide full-duplex communication channels over a single TCP connection."
  },
  {
    question: "What does ACID stand for in databases?",
    options: ["Atomicity, Consistency, Isolation, Durability", "Access, Control, Interface, Data", "Auto, Correlated, Index, Delete", "Association, Connectivity, Integration, Development"],
    answer: "Atomicity, Consistency, Isolation, Durability",
    explanation: "ACID properties ensure reliable processing of database transactions."
  },
  {
    question: "Which type of database is MongoDB?",
    options: ["Relational (SQL)", "Document-oriented (NoSQL)", "Graph", "Key-Value"],
    answer: "Document-oriented (NoSQL)",
    explanation: "MongoDB stores data in flexible, JSON-like documents."
  },
  {
    question: "In SQL, which clause is used to filter records?",
    options: ["SELECT", "WHERE", "GROUP BY", "ORDER BY"],
    answer: "WHERE",
    explanation: "The WHERE clause is used to filter records."
  },
  {
    question: "What is Normalization?",
    options: ["Backing up data", "Organizing data to reduce redundancy", "Creating an index", "Deleting old data"],
    answer: "Organizing data to reduce redundancy",
    explanation: "Normalization is the process of structuring a database to reduce data redundancy and improve data integrity."
  },
  {
    question: "What is an Index in a database?",
    options: ["A list of all tables", "A data structure that improves the speed of data retrieval", "A primary key", "A stored procedure"],
    answer: "A data structure that improves the speed of data retrieval",
    explanation: "Indexes are used to quickly locate data without having to search every row in a database table."
  },
  {
    question: "What is the difference between specificities of INNER JOIN and LEFT JOIN?",
    options: ["No difference", "INNER JOIN returns only matching rows, LEFT JOIN returns all rows from left table", "LEFT JOIN returns only matching", "INNER JOIN returns all rows"],
    answer: "INNER JOIN returns only matching rows, LEFT JOIN returns all rows from left table",
    explanation: "INNER JOIN selects records with matching values in both tables; LEFT JOIN returns all from the left, unmatched from right are NULL."
  },
  {
    question: "Which command is used to remove a table definition and all its data?",
    options: ["DELETE", "TRUNCATE", "DROP", "REMOVE"],
    answer: "DROP",
    explanation: "DROP TABLE removes the table structure and its data entirely."
  },
  {
    question: "What is the primary key?",
    options: ["Any unique column", "A column that uniquely identifies each record", "The first column", "A foreign link"],
    answer: "A column that uniquely identifies each record",
    explanation: "A primary key must contain unique values and cannot contain NULL values."
  },
  {
    question: "What is the 'N+1 problem'?",
    options: ["A sorting algorithm issue", "Fetching data in a loop resulting in N+1 queries", "An index error", "A stack overflow"],
    answer: "Fetching data in a loop resulting in N+1 queries",
    explanation: "The N+1 problem occurs when code executes N additional query statements to fetch the same data that could have been retrieved when executing the primary query."
  },
  {
    question: "What is Redis typically used for?",
    options: ["Long-term cold storage", "In-memory caching", "Relational mapping", "Vector graphics"],
    answer: "In-memory caching",
    explanation: "Redis is an in-memory data structure store, used as a database, cache, and message broker."
  },
  {
    question: "What is the primary function of Docker?",
    options: ["To compile code", "To containerize applications", "To manage databases", "To balance network load"],
    answer: "To containerize applications",
    explanation: "Docker packages an application and its dependencies into a container to ensure consistency across environments."
  },
  {
    question: "What does CI/CD stand for?",
    options: ["Continuous Integration / Continuous Deployment", "Code Inspection / Code Delivery", "Cloud Integration / Cloud Distribution", "Central Interface / Central Database"],
    answer: "Continuous Integration / Continuous Deployment",
    explanation: "CI/CD automates the app development lifecycle from integration and testing to delivery and deployment."
  },
  {
    question: "Which of the following is a reverse proxy?",
    options: ["React", "Nginx", "MongoDB", "Git"],
    answer: "Nginx",
    explanation: "Nginx is often used as a reverse proxy, load balancer, and HTTP cache."
  },
  {
    question: "What is the purpose of a Load Balancer?",
    options: ["To compress files", "To distribute network traffic across multiple servers", "To encrypt data", "To detailed logs"],
    answer: "To distribute network traffic across multiple servers",
    explanation: "Load balancers improve the responsiveness and availability of applications by distributing load."
  },
  {
    question: "What does 'git rebase' do?",
    options: ["Merges two branches", "Moves or combines a sequence of commits to a new base commit", "Deletes a branch", "Pushes code to remote"],
    answer: "Moves or combines a sequence of commits to a new base commit",
    explanation: "Rebasing re-writes the project history by creating new commits for the original changes."
  },
  {
    question: "In the context of the 12-Factor App, where should config be stored?",
    options: ["In the database", "In the code", "In the environment", "In a dedicated server"],
    answer: "In the environment",
    explanation: "The 12-factor apps store config in environment variables to separate config from code."
  },
  {
    question: "What is Horizontal Scaling?",
    options: ["Adding more power (CPU, RAM) to an existing machine", "Adding more machines to the pool of resources", "Optimizing code", "Reducing database size"],
    answer: "Adding more machines to the pool of resources",
    explanation: "Horizontal scaling (scaling out) involves adding more server instances to handle load."
  },
  {
    question: "What is Serverless computing?",
    options: ["Running apps without ANY hardware", "Cloud provider manages the server allocation dynamically", "Peer-to-peer networking", "Localhost development"],
    answer: "Cloud provider manages the server allocation dynamically",
    explanation: "Serverless lets developers build and run applications without managing infrastructure (e.g., AWS Lambda)."
  },
  {
    question: "What is CORS?",
    options: ["Cross-Origin Resource Sharing", "Central Origin Route System", "Cascading Origin Resource Style", "Code Optimization Resource Standard"],
    answer: "Cross-Origin Resource Sharing",
    explanation: "CORS is a security feature that restricts web pages from making requests to a different domain than the one that served the web page."
  },
  {
    question: "What is Blue-Green deployment?",
    options: ["Color coding code comments", "A technique to reduce downtime by running two identical production environments", "Deploying only at night", "Using eco-friendly servers"],
    answer: "A technique to reduce downtime by running two identical production environments",
    explanation: "One environment (Blue) is live, while the other (Green) is updated. Switching traffic to Green releases the new version."
  }
];
