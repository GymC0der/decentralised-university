// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DecentralisedUniversity
 * @dev Smart contract for managing a decentralised university system
 * @author Decentralised University Team
 */
contract DecentralisedUniversity {
    
    // Structs
    struct Student {
        address studentAddress;
        string name;
        string email;
        bool isEnrolled;
        uint256 enrollmentDate;
        mapping(uint256 => bool) completedCourses;
        uint256[] enrolledCourses;
    }
    
    struct Course {
        uint256 courseId;
        string courseName;
        string description;
        address instructor;
        uint256 credits;
        uint256 fee;
        bool isActive;
        uint256 creationDate;
        address[] enrolledStudents;
    }
    
    struct Certificate {
        uint256 certificateId;
        address student;
        uint256 courseId;
        string courseName;
        uint256 issueDate;
        bool isValid;
        string ipfsHash; // For storing certificate metadata
    }
    
    // State variables
    address public admin;
    uint256 public totalStudents;
    uint256 public totalCourses;
    uint256 public totalCertificates;
    
    // Mappings
    mapping(address => Student) public students;
    mapping(uint256 => Course) public courses;
    mapping(uint256 => Certificate) public certificates;
    mapping(address => bool) public authorizedInstructors;
    mapping(address => uint256[]) public studentCertificates;
    
    // Events
    event StudentEnrolled(address indexed student, string name, uint256 timestamp);
    event CourseCreated(uint256 indexed courseId, string courseName, address instructor);
    event StudentEnrolledInCourse(address indexed student, uint256 indexed courseId);
    event CertificateIssued(uint256 indexed certificateId, address indexed student, uint256 indexed courseId);
    event InstructorAuthorized(address indexed instructor);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyAuthorizedInstructor() {
        require(authorizedInstructors[msg.sender], "Only authorized instructors can perform this action");
        _;
    }
    
    modifier onlyEnrolledStudent() {
        require(students[msg.sender].isEnrolled, "Only enrolled students can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        totalStudents = 0;
        totalCourses = 0;
        totalCertificates = 0;
    }
    
    /**
     * @dev Core Function 1: Student Enrollment
     * @param _name Student's full name
     * @param _email Student's email address
     */
    function enrollStudent(string memory _name, string memory _email) public {
        require(!students[msg.sender].isEnrolled, "Student already enrolled");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        
        Student storage newStudent = students[msg.sender];
        newStudent.studentAddress = msg.sender;
        newStudent.name = _name;
        newStudent.email = _email;
        newStudent.isEnrolled = true;
        newStudent.enrollmentDate = block.timestamp;
        
        totalStudents++;
        
        emit StudentEnrolled(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Course Creation and Management
     * @param _courseName Name of the course
     * @param _description Course description
     * @param _credits Number of credits for the course
     * @param _fee Course fee in wei
     */
    function createCourse(
        string memory _courseName,
        string memory _description,
        uint256 _credits,
        uint256 _fee
    ) public onlyAuthorizedInstructor {
        require(bytes(_courseName).length > 0, "Course name cannot be empty");
        require(_credits > 0, "Credits must be greater than 0");
        
        uint256 courseId = totalCourses + 1;
        
        Course storage newCourse = courses[courseId];
        newCourse.courseId = courseId;
        newCourse.courseName = _courseName;
        newCourse.description = _description;
        newCourse.instructor = msg.sender;
        newCourse.credits = _credits;
        newCourse.fee = _fee;
        newCourse.isActive = true;
        newCourse.creationDate = block.timestamp;
        
        totalCourses++;
        
        emit CourseCreated(courseId, _courseName, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Certificate Issuance and Verification
     * @param _student Student's address
     * @param _courseId Course ID for which certificate is being issued
     * @param _ipfsHash IPFS hash containing certificate metadata
     */
    function issueCertificate(
        address _student,
        uint256 _courseId,
        string memory _ipfsHash
    ) public onlyAuthorizedInstructor {
        require(students[_student].isEnrolled, "Student not enrolled");
        require(courses[_courseId].isActive, "Course does not exist or is inactive");
        require(courses[_courseId].instructor == msg.sender, "Only course instructor can issue certificates");
        require(students[_student].completedCourses[_courseId], "Student has not completed this course");
        
        uint256 certificateId = totalCertificates + 1;
        
        Certificate storage newCertificate = certificates[certificateId];
        newCertificate.certificateId = certificateId;
        newCertificate.student = _student;
        newCertificate.courseId = _courseId;
        newCertificate.courseName = courses[_courseId].courseName;
        newCertificate.issueDate = block.timestamp;
        newCertificate.isValid = true;
        newCertificate.ipfsHash = _ipfsHash;
        
        studentCertificates[_student].push(certificateId);
        totalCertificates++;
        
        emit CertificateIssued(certificateId, _student, _courseId);
    }
    
    // Additional helper functions
    
    /**
     * @dev Authorize an instructor
     * @param _instructor Address of the instructor to authorize
     */
    function authorizeInstructor(address _instructor) public onlyAdmin {
        require(_instructor != address(0), "Invalid instructor address");
        authorizedInstructors[_instructor] = true;
        emit InstructorAuthorized(_instructor);
    }
    
    /**
     * @dev Enroll in a course
     * @param _courseId Course ID to enroll in
     */
    function enrollInCourse(uint256 _courseId) public payable onlyEnrolledStudent {
        require(courses[_courseId].isActive, "Course does not exist or is inactive");
        require(msg.value >= courses[_courseId].fee, "Insufficient fee payment");
        
        courses[_courseId].enrolledStudents.push(msg.sender);
        students[msg.sender].enrolledCourses.push(_courseId);
        
        // Transfer fee to instructor
        payable(courses[_courseId].instructor).transfer(msg.value);
        
        emit StudentEnrolledInCourse(msg.sender, _courseId);
    }
    
    /**
     * @dev Mark course as completed for a student
     * @param _student Student's address
     * @param _courseId Course ID
     */
    function markCourseCompleted(address _student, uint256 _courseId) public onlyAuthorizedInstructor {
        require(courses[_courseId].instructor == msg.sender, "Only course instructor can mark completion");
        students[_student].completedCourses[_courseId] = true;
    }
    
    /**
     * @dev Verify a certificate
     * @param _certificateId Certificate ID to verify
     * @return bool Certificate validity
     */
    function verifyCertificate(uint256 _certificateId) public view returns (bool) {
        return certificates[_certificateId].isValid;
    }
    
    /**
     * @dev Get student's certificates
     * @param _student Student's address
     * @return uint256[] Array of certificate IDs
     */
    function getStudentCertificates(address _student) public view returns (uint256[] memory) {
        return studentCertificates[_student];
    }

    
    function getCourseDetails(uint256 _courseId) public view returns (
        string memory courseName,
        string memory description,
        address instructor,
        uint256 credits,
        uint256 fee,
        bool isActive
    ) {
        Course storage course = courses[_courseId];
        return (
            course.courseName,
            course.description,
            course.instructor,
            course.credits,
            course.fee,
            course.isActive
        );
    }
    
    /**
     * @dev Emergency function to pause/unpause a course
     * @param _courseId Course ID
     * @param _isActive New active status
     */
    function setCourseStatus(uint256 _courseId, bool _isActive) public onlyAdmin {
        courses[_courseId].isActive = _isActive;
    }
}
